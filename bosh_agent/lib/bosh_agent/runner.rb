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
        
        if Bosh::Agent::Config.state and Bosh::Agent::Config.state["passive"].to_s == "enabled"
          @logger.info("Disabling monit startup as in passive mode")
        else
          
          if Bosh::Agent::Config.state and Bosh::Agent::Config.state["drbd_enabled"] 
            Bosh::Agent::Drbd.drbd_mount(File.join(Bosh::Agent::Config.base_dir, 'store'))
          else
            bootstrap.mount_persistent_disk
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
