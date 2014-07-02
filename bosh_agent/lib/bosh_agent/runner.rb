module Bosh::Agent
  class Runner
    def self.run(options)
      Config.setup(options)
      Runner.new.start
    end

    def initialize
      @logger = Config.logger
    end

    def start
      $stdout.sync = true
      @logger.info("Starting agent #{VERSION}...")

      @logger.info('Configuring agent...')
      bootstrap = Bootstrap.new
      bootstrap.configure

      if Config.configure
        Monit.enable
        Monit.start
        
        if Config.state and Config.state["passive"].to_s == "enabled"
          @logger.info("Disabling monit startup as in passive mode")
        else
          
          if Config.state and Config.state["drbd_enabled"] 
            Drbd.drbd_mount(File.join(Config.base_dir, 'store'))
          else
            bootstrap.mount_persistent_disk
          end
          
          if Config.state and Config.state["dns_register_on_start"]
            Bosh::Agent::Dns.update_dns_servers()
          end
          
          Monit.start_services
        end
      end

      if Config.mbus.start_with?('https')
        @logger.info('Starting up https agent')
        require 'bosh_agent/http_handler'
        HTTPHandler.start
      else
        Handler.start
      end
    end
  end
end
