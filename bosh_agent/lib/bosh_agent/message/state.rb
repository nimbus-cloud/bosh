# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent
  module Message
    class State < Base

      def self.process(args)
        self.new(args).state
      end

      def initialize(args = nil)
        if args.is_a?(Array)
          @full_format = true if args.include?("full")
        end
      end

      def state
        response = Bosh::Agent::Config.state.to_hash

        logger.info("Agent state: #{response.inspect}")

        if settings
          response["agent_id"] = settings["agent_id"]
          response["vm"] = settings["vm"]
        end

        response["job_state"] = job_state
        response["bosh_protocol"] = Bosh::Agent::BOSH_PROTOCOL
        response["ntp"] = Bosh::Agent::NTP.offset

        if @full_format
          response["vitals"] = Bosh::Agent::Monit.get_vitals
          response["vitals"]["disk"] = Bosh::Agent::DiskUtil.get_usage
        end
        
        response["drbd"] = {}
        drbd = response["drbd"] 
        
        if File.file?("/proc/drbd")
          file = File.open("/proc/drbd", "r")
          file.each_line do |line|
            if line=~/cs:(\S+)\s+ro:(\S+)\s+ds:(\S+)/
              drbd["connection_state"]=$1
              drbd["role"]=$2
              drbd["disk_state"]=$3
            end
            if line=~/\s*[\[\>\.\]]+\s*sync'ed:\s*(.+)/
              drbd["sync_state"]=$1
            end
            if line=~/^\s*(finish:.+)$/
              drbd["sync_state"]="#{drbd["sync_state"]} #{$1}"
            end
          end
          file.close
        else
          drbd["connection_state"]="not running"
          drbd["role"]=""
          drbd["disk_state"]=""
          drbd["sync_state"]=""
        end

        response

      rescue Bosh::Agent::StateError => e
        raise Bosh::Agent::MessageHandlerError, e
      end

      def job_state
        Bosh::Agent::Config.state["passive"].to_s == "enabled" ? "passive" : Bosh::Agent::Monit.service_group_state
      end
    end
  end
end
