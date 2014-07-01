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
        
          # mount has now been moved to the start job
          Bosh::Agent::Config.platform.lookup_disk_by_cid(@cid)
        end
      end

      def update_settings
        Bosh::Agent::Config.settings = Bosh::Agent::Settings.load
      end

      def self.long_running?; true; end
    end

  end
end
