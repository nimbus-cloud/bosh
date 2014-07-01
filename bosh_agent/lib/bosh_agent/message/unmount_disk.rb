require 'bosh_agent/disk_util'

module Bosh::Agent
  module Message
    class UnmountDisk < Base

      def self.long_running?; true; end

      def self.process(args)
        self.new.unmount(args)
      end

      def unmount(args)
        cid = args.first

        # unmount has now been moved to the stop job
        return {:message => "Unmounted is deprecated" }
      end
    end
  end
end
