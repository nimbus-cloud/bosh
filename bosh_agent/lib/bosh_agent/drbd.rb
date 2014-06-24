require 'erb'
require 'socket'
require 'fileutils'

module Bosh::Agent
  
  class Drbd
    class << self
      attr_accessor :enabled

      A_ROOT_SERVER = '198.41.0.4'
      
      DRBD_TEMPLATE = <<-ERB
resource r0 {
  net {
    protocol <%= drbd_replication_type %>;
    shared-secret <%= drbd_secret %>;
  }
  disk {
    resync-rate 10M;
  }
  handlers {
    before-resync-target "/lib/drbd/snapshot-resync-target-lvm.sh";
    after-resync-target "/lib/drbd/unsnapshot-resync-target-lvm.sh";
  }
  startup {
    wfc-timeout 3;
    degr-wfc-timeout 3;
    outdated-wfc-timeout 2;
  }
  on <%= drbd_host1_name %> {
    device    drbd1;
    disk      <%= drbd_replication_disk %>;
    address   <%= drbd_replication_node1 %>:7789;
    meta-disk internal;
  }
  on <%= drbd_host2_name %> {
    device    drbd1;
    disk      <%= drbd_replication_disk %>;
    address   <%= drbd_replication_node2 %>:7789;
    meta-disk internal;
  }
}
ERB

      def local_ip(route = A_ROOT_SERVER)
        route ||= A_ROOT_SERVER
        orig, Socket.do_not_reverse_lookup = Socket.do_not_reverse_lookup, true
        UDPSocket.open {|s| s.connect(route, 1); s.addr.last }
      ensure
        Socket.do_not_reverse_lookup = orig
      end
      
              
      def generate_config
        Bosh::Agent::Config.logger.info "Regenerating DRBD Config"
  
        state = Bosh::Agent::Config.state
  
        drbd_replication_type = state["drbd_replication_type"].to_s
        (drbd_replication_type=~/^[ABC]$/) or raise "drbd_replication_type needs to be either A, B or C"
        
        drbd_replication_disk = "/dev/mapper/vgStoreData-StoreData"
        
        drbd_replication_node1 = state["drbd_replication_node1"].to_s
        (drbd_replication_node1 =~ /^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/) or raise "drbd_replication_node1 needs to be a valid ip"
          
        drbd_replication_node2 = state["drbd_replication_node2"].to_s
        (drbd_replication_node2 =~ /^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/) or raise "drbd_replication_node1 needs to be a valid ip"
        
        drbd_host1_name = "host1"
        drbd_host2_name = "host2"
        
        myip = local_ip
        drbd_host1_name = Socket.gethostname if local_ip == drbd_replication_node1
        drbd_host2_name = Socket.gethostname if local_ip == drbd_replication_node2
        
        drbd_secret = state["drbd_secret"].to_s
        drbd_secret != "" or raise "secret must be set"
          
        template = ERB.new(DRBD_TEMPLATE)
        
        File.open("/etc/drbd.d/r0.res", 'wb') do |file|
          file.puts(template.result(binding))
        end
        
      end
      
      def drbd_restart
        Bosh::Exec.sh("/etc/init.d/drbd restart 2>&1")
      end
      
      def drbd_startup
        generate_config
        create_lvm
        drbd_restart
        drbd_create_partition
      end
      
      def drbd_create_md
        Bosh::Exec.sh("drbdadm create-md r0 2>&1")
        Bosh::Exec.sh("drbdadm up r0 2>&1")
      end
      
      def drbd_make_primary        
        Bosh::Agent::Config.logger.info "Making primary"
        force_flag = ""
        if Bosh::Agent::Config.state["drbd_force_master"]
          force_flag = "--force"
        end
        Bosh::Exec.sh("drbdadm primary #{force_flag} r0 2>&1")
      end
      
      def drbd_make_secondary
        Bosh::Agent::Config.logger.info "Making secondary"
        Bosh::Exec.sh("drbdadm secondary r0 2>&1")        
      end
    
      def create_lvm
        
        cids = Bosh::Agent::Config.settings["disks"]["persistent"]
        i = 0
        disk = nil 
        cids.each_key do |cid|
          if i != 0 
            raise "Mutliple persistent disks available. Panic!"
          end
          disk = Bosh::Agent::Config.platform.lookup_disk_by_cid(cid)
          i = i + 1
        end
        
        disk.nil? and raise "No persistent disk present"
        
        results = Bosh::Exec.sh("pvs")
        unless (results.output.include?(disk))
          Bosh::Exec.sh("pvcreate #{disk}")
          Bosh::Exec.sh("vgcreate vgStoreData #{disk}")
        end
        
        results = Bosh::Exec.sh("lvs")
        unless (results.output =~ /StoreData\s+vgStoreData/m)
          # Leave 10% for lvm snapshots
          Bosh::Exec.sh("lvcreate -n StoreData -l 40%FREE vgStoreData");
        end
      
      end
      
      def drbd_create_partition
        
        results = Bosh::Exec.sh("drbdadm dstate r0 2>&1")
        return if results.output !~ /^Diskless\//
        
        results = Bosh::Exec.sh("drbdadm dump-md r0 2>&1", on_error: :return)
        if results.output=~/No valid meta data found/
           Bosh::Exec.sh("/bin/bash -c \"echo 'no' | drbdadm create-md r0\" 2>&1")
        elsif results.exit_status != 0 
          raise "Failure: drbdadm dump-md r0 2>&1. Output: #{results.output}"
        end
    
        Bosh::Exec.sh("drbdadm down r0 2>&1")
        Bosh::Exec.sh("drbdadm up r0 2>&1")
        
      end
      
      def drbd_check_partition
        
        logger = Bosh::Agent::Config.logger
        logger.info("setup disk settings: /dev/drbd1")
        partition = "/dev/drbd1"
        
        #Add additional check for "force" and not format unless we are forcing.
        result = Bosh::Exec.sh("file -s /dev/drbd1")
        if result.output=~/^\/dev\/drbd1: data/
          mke2fs_options = ["-t ext4", "-j"]
          mke2fs_options << "-E lazy_itable_init=1" if Bosh::Agent::Util.lazy_itable_init_enabled?
          `/sbin/mke2fs #{mke2fs_options.join(" ")} #{partition}`
          unless $?.exitstatus == 0
            raise Bosh::Agent::MessageHandlerError, "Failed create file system (#{$?.exitstatus})"
          end
        end
      end
      
      def drbd_mount(mount_point)
        Bosh::Agent::Config.logger.info "DRBD MOUNT"
        drbd_make_primary
        
        FileUtils.mkdir_p(mount_point)
        FileUtils.chmod(0755, mount_point)
        
        drbd_check_partition()
        
        results = Bosh::Exec.sh("mount /dev/drbd1 #{mount_point} 2>&1")
      end
      
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
      
      def safe_umount(mount_point)
        return if !is_mounted?(mount_point)
          
        results = nil
        for i in 0..15
          results = Bosh::Exec.sh("umount #{mount_point} 2>&1", on_error: :return)
          return true if results.exit_status == 0
          if results.output !~ /device is busy/
            raise "Command: umount #{mount_point} failed. #{results.output}"
          end
          sleep 1
        end
        #TODO: Maybe try something more forceful? Kill some processes? 
        raise "umount #{mount_point} failed after 15 attempts. Last error: #{results.output}"
      end
      
      def drbd_umount(mount_point)
        
        Bosh::Agent::Config.logger.info "DRBD UMOUNT"
        DiskUtil.umount_guard(mount_point) if is_mounted?(mount_point)
        # TODO: Only run if you are primary? maybe this is safe
        drbd_make_secondary
      end
      
    end
  end
end
