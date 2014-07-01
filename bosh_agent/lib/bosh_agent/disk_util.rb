module Bosh::Agent
  class DiskUtil
    class << self
      def logger
        Bosh::Agent::Config.logger
      end

      def base_dir
        Bosh::Agent::Config.base_dir
      end

      def normal_mount_format(cid, mountpoint)
        
        disk = Bosh::Agent::Config.platform.lookup_disk_by_cid(cid)
        partition = "#{disk}1"
        
        read_disk_attempts = 300
        read_disk_attempts.downto(0) do |n|
          begin
            # Parition table is blank
            disk_data = File.read(disk, 512)

            if disk_data == "\x00"*512
              Bosh::Agent::Config.logger.info("Found blank disk #{disk}")
            else
              Bosh::Agent::Config.logger.info("Disk has partition table")
              Bosh::Agent::Config.logger.info(`sfdisk -Llq #{disk} 2> /dev/null`)
            end
            break
          rescue => e
            # Do nothing - we'll retry
            Bosh::Agent::Config.logger.info("Re-trying reading from #{disk}")
          end

          if n == 0
            raise Bosh::Agent::MessageHandlerError, "Unable to read from new disk"
          end
          sleep 1
        end

        if File.blockdev?(disk) && DiskUtil.ensure_no_partition?(disk, partition)
          full_disk = ",,L\n"
          Bosh::Agent::Config.logger.info("Partitioning #{disk}")

          Bosh::Agent::Util.partition_disk(disk, full_disk)

          mke2fs_options = ["-t ext4", "-j"]
          mke2fs_options << "-E lazy_itable_init=1" if Bosh::Agent::Util.lazy_itable_init_enabled?
          `/sbin/mke2fs #{mke2fs_options.join(" ")} #{partition}`
          unless $?.exitstatus == 0
            raise Bosh::Agent::MessageHandlerError, "Failed create file system (#{$?.exitstatus})"
          end
        elsif File.blockdev?(partition)
          Bosh::Agent::Config.logger.info("Found existing partition on #{disk}")
        else
          raise Bosh::Agent::MessageHandlerError, "Unable to format #{disk}"
        end

        unless File.read('/proc/mounts').lines.select { |l| l.match(/#{disk}1/) }.first
          Bosh::Agent::Config.logger.info("Startup: mounting #{disk}1 at #{mountpoint}")
          Mounter.new(Bosh::Agent::Config.logger).mount(partition, mountpoint)
        end
      end
      
      def mount_entry(partition)
        File.read('/proc/mounts').lines.select { |l| l.match(/#{partition}/) }.first
      end

      GUARD_RETRIES = 600
      GUARD_SLEEP = 1

      def is_mounted?(mount_point)
      
        results = Bosh::Exec.sh("mount 2>&1")
        
        raise "Command: mount failed. #{results.output}" if results.exit_status != 0
        
        results.output.split( /\r?\n/ ).each do |line|
          if line =~ /\son\s(\S+)/
            return true if ($1 == mount_point)   
          end
        end
        false
      end
      
      def umount_guard(mountpoint)
        
        if is_mounted?(mountpoint) == false
          logger.info("mountpoint is already unmounted")
          return
        end
        
        umount_attempts = GUARD_RETRIES
        loop do
          umount_output = `umount #{mountpoint} 2>&1`

          if $?.exitstatus == 0
            break
          elsif umount_attempts != 0 && umount_output =~ /device is busy/
            #when umount2 syscall fails and errno == EBUSY, umount.c outputs:
            # "umount: %s: device is busy.\n"
            sleep GUARD_SLEEP
            umount_attempts -= 1
          else
            raise Bosh::Agent::MessageHandlerError,
                  "Failed to umount #{mountpoint}: #{umount_output}"
          end
        end

        attempts = GUARD_RETRIES - umount_attempts
        logger.info("umount_guard #{mountpoint} succeeded (#{attempts})")
      end

      # Pay a penalty on this check the first time a persistent disk is added to a system
      def ensure_no_partition?(disk, partition)
        check_count = 2
        check_count.times do
          if sfdisk_lookup_partition(disk, partition).empty?
            # keep on trying
          else
            if File.blockdev?(partition)
              return false # break early if partition is there
            end
          end
          sleep 1
        end

        # Double check that the /dev entry is there
        if File.blockdev?(partition)
          return false
        else
          return true
        end
      end

      def sfdisk_lookup_partition(disk, partition)
        `sfdisk -Llq #{disk}`.lines.select { |l| l.match(%q{/\A#{partition}.*83.*Linux}) }
      end

      def get_usage
        usage = {
          system: fs_usage_safe('/')
        }
        ephemeral_percent = fs_usage_safe(File.join(base_dir, 'data'))
        usage[:ephemeral] = ephemeral_percent if ephemeral_percent
        persistent_percent = fs_usage_safe(File.join(base_dir, 'store'))
        usage[:persistent] = persistent_percent if persistent_percent

        usage
      end

      private
      # Calculate file_system_usage
      def fs_usage_safe(path)
        sigar = SigarBox.create_sigar
        fs_list = sigar.file_system_list

        fs = fs_list.find {|fs| fs.dir_name == path}
        return unless fs

        usage = sigar.file_system_usage(path)
        space_usage_percent = (usage.use_percent * 100)

        # inode pct calculation taken from 'df' src
        # http://lingrok.org/xref/coreutils/src/df.c
        inode_total = usage.files
        inode_used_100 = (inode_total - usage.free_files) * 100
        inode_usage_percent = inode_used_100 / inode_total + (inode_used_100 % inode_total != 0 ? 1 : 0)

        { percent: space_usage_percent.to_i.to_s, inode_percent: inode_usage_percent.to_i.to_s }
      end

    end
  end
end
