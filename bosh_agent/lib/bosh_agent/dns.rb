require 'fiber'

module Bosh::Agent
  
  class Dns
    class << self
      attr_accessor :enabled

      def start_dns_updates

        unless $dns_timer
          logger.info("Scheduling dynamic DNS updates")
          $dns_timer = EM.add_periodic_timer(60) do
            begin
              Fiber.new { update_dns_servers }.resume
            rescue Exception => e
              logger.error("Dynamic dns update exception. Error #{e.message}. Backtrace #{e.backtrace}.")
            end
          end
        end

        EM.next_tick do
          begin
            Fiber.new { update_dns_servers }.resume
          rescue Exception => e
            logger.error("Dynamic dns update exception. Error #{e.message}. Backtrace #{e.backtrace}.")
          end
        end
      end
      
      def stop_dns_updates
        logger.info("Disabled dynamic DNS updates")
        $dns_timer.cancel if $dns_timer
        $dns_timer = nil
      end
      
      def update_dns_servers
        
        if Bosh::Agent::Config.state and Config.state["passive"].to_s == "enabled"
          logger.info "Not updating dynamic dns as I'm passive"
          return
        end
        
        state = Bosh::Agent::Config.state
        properties = state["properties"]
       
        return unless state["dns_register_on_start"]
        return unless properties["dns"]
        return unless properties["dns"]["ttl"]
        return unless properties["dns"]["key"]
        return unless properties["dns"]["dnsservers"]

        logger.info "DNS Register"
          
        tmpdir = Dir.mktmpdir
        properties["dns"]["dnsservers"].each do |dns_server|
          generate_ns_file(tmpdir, state, properties, dns_server)
          cmd = execute_command_fibered("nsupdate -t 4 -y #{properties["dns"]["key"]} -v #{tmpdir}/update-#{dns_server}.ns", 5)
          if (cmd[:status] != 0)
            logger.error "DNS Register failed with #{cmd[:output]}"
          end
        end
        FileUtils.rm_rf(tmpdir)
      end
     
      def get_ip_addr
        Bosh::Agent::Config.state["networks"].each_key do |network|
          # not sure this is reliable.
          logger.info "Return ip for network #{network}"
          return Bosh::Agent::Config.state["networks"][network]["ip"]
        end
        raise "Unable to determine ip address"
      end
     
      def generate_ns_file(tmpdir, state, properties, dns_server)

        state["dns_register_on_start"] =~ /^[^.]+\.(.+)$/
        zone = $1
        raise ("unable to determine zone from #{state["dns_register_on_start"]}") unless zone
       
        File.open(File.join(tmpdir, "update-#{dns_server}.ns"), 'wb') do |file|
          file.puts("server #{dns_server}")
          file.puts("zone #{zone}")
          file.puts("update delete #{state['dns_register_on_start']} A ")
          file.puts("update add #{state['dns_register_on_start']} #{properties["dns"]["ttl"]} A #{get_ip_addr}")
          file.puts("send")
          file.puts("")
        end
      end
      
      def logger
        Bosh::Agent::Config.logger
      end
      
      def safe_command(command)
        command.gsub(/-y\s+\S+/, '-y ********')
      end
      
      def execute_command_fibered(command, timeout)
        f = Fiber.current
        commandTimedOut = false
        result = {}
        logger.debug("Executing timeout #{timeout} fibered : #{safe_command(command)}")
                
        command_proc = proc do |p|
        end
        
        cont_proc = proc do |output, status|
          f.resume({:status => status, :output => output})
        end
        
        pid=EM.system("#{command} 2>&1", command_proc, cont_proc)
        
        timer=nil
        if timeout!=nil
          timer=EM.add_timer(timeout) do
            # Depending upon the process tree the kill might not happen straight away
            # Linux is a slacker about killing the child processes
            Process.kill(9, pid)
            logger.debug("Command TIMEOUT after #{timeout} for command #{safe_command(command)}")
            commandTimedOut=true  
          end
        end
        result = Fiber.yield
        EM.cancel_timer(timer)
        if commandTimedOut
          result[:output] = "#{result[:output]}. TIMEOUT!"
        end
        result[:status] = result[:status].exitstatus
        logger.debug("Fibered result #{result[:status]}")
        result
      end
    end
  end
end
