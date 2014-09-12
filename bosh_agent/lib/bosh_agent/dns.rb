

module Bosh::Agent
  
  class Dns
    class << self
      attr_accessor :enabled

      def start_dns_updates
        unless $dns_timer
          Config.logger.info("Scheduling dynamic DNS updates")
          $dns_timer = EM.add_periodic_timer(60) do
            update_dns_servers
          end
        end
        update_dns_servers
      end
      
      def stop_dns_updates
        Config.logger.info("Disabled dynamic DNS updates")
        $dns_timer.cancel if $dns_timer
        $dns_timer = nil
      end
      
      def update_dns_servers
        
        if Bosh::Agent::Config.state and Config.state["passive"].to_s == "enabled"
          Bosh::Agent::Config.logger.info "Not updating dynamic dns as I'm passive"
          return
        end
        
        state = Bosh::Agent::Config.state
        properties = state["properties"]
       
        return unless state["dns_register_on_start"]
        return unless properties["dns"]
        return unless properties["dns"]["ttl"]
        return unless properties["dns"]["key"]
        return unless properties["dns"]["dnsservers"]

        Bosh::Agent::Config.logger.info "DNS Register"
          
        tmpdir = Dir.mktmpdir
        generate_ns_file(tmpdir, state, properties)
        
        cmd = Bosh::Exec.sh("nsupdate -y #{properties["dns"]["key"]} -v #{tmpdir}/update.ns 2>&1", on_error: :return)
        if (cmd.exit_status != 0)
          Bosh::Agent::Config.logger.info "DNS Register failed with #{cmd.output}"
        end
        
        FileUtils.rm_rf(tmpdir)
      end
     
      def get_ip_addr
        Bosh::Agent::Config.state["networks"].each_key do |network|
          Bosh::Agent::Config.logger.info "Return ip for network #{network}"
          return Bosh::Agent::Config.state["networks"][network]["ip"]
        end
        raise "Unable to determine ip address"
      end
     
      def generate_ns_file(tmpdir, state, properties)

        state["dns_register_on_start"] =~ /^[^.]+\.(.+)$/
        zone = $1
        return unless zone
       
        File.open(File.join(tmpdir, "update.ns"), 'wb') do |file|
          properties["dns"]["dnsservers"].each do |dnsserver|
            file.puts("server #{dnsserver}")
            file.puts("zone #{zone}")
            file.puts("update delete #{state['dns_register_on_start']} A ")
            file.puts("update add #{state['dns_register_on_start']} #{properties["dns"]["ttl"]} A #{get_ip_addr}")
            file.puts("send")
            file.puts("")
          end
        end

      end      
    end
  end
end