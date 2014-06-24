# Copyright (c) 2009-2012 VMware, Inc.
require 'bosh_agent/mounter'

module Bosh::Agent
  module Message
    class MountDisk < Base
      def self.process(args)
        new(args).mount
      end

      def initialize(args)
        @cid = args.first
      end

      def mount
        if Bosh::Agent::Config.configure
          update_settings
          logger.info("MountDisk: #{@cid} - #{settings['disks'].inspect}")
          
          if Bosh::Agent::Config.state and Bosh::Agent::Config.state["drbd_enabled"]
            logger.info("Skipping disk initialization I'm a DRBD box")
          else
            setup_disk
          end
          
        end
      end

      def update_settings
        Bosh::Agent::Config.settings = Bosh::Agent::Settings.load
      end

      def setup_disk
        disk = Bosh::Agent::Config.platform.lookup_disk_by_cid(@cid)
        partition = "#{disk}1"

        logger.info("setup disk settings: #{settings.inspect}")

        #mount_persistent_disk(partition)
        {}
      end

      def mount_persistent_disk(partition)
        store_mountpoint = File.join(base_dir, 'store')

        if Pathname.new(store_mountpoint).mountpoint?
          logger.info("Mounting persistent disk store migration target")
          mountpoint = File.join(base_dir, 'store_migraton_target')
        else
          logger.info("Mounting persistent disk store")
          mountpoint = store_mountpoint
        end

        FileUtils.mkdir_p(mountpoint)
        FileUtils.chmod(0700, mountpoint)

        Mounter.new(logger).mount(partition, mountpoint)
      end

      def self.long_running?; true; end
    end

  end
end
