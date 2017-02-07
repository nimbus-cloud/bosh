require 'bosh/dev'
require 'bosh/core/shell'

module Bosh::Dev::Sandbox
  class Sqlite
    attr_reader :db_name, :username, :password, :port, :adapter

    def initialize(db_name, logger, runner = Bosh::Core::Shell.new)
      @db_name = db_name
      @logger = logger
      @runner = runner
      @username = nil
      @password = nil
      @port = nil
      @adapter = 'sqlite'
    end

    def connection_string
      "sqlite://#{@db_name}"
    end

    def create_db
      @logger.info("Creating sqlite database #{db_name}")
    end

    def drop_db
      @logger.info("Dropping sqlite database #{db_name}")
      @runner.run("rm #{@db_name}")
    end

    def current_tasks
      raise '"#current_tasks" not supported for sqlite'
    end

    def current_locked_jobs
      raise '"#current_locked_jobs" not supported for sqlite'
    end

    def truncate_db
      @logger.info("Truncating sqlite database #{db_name}")
      @runner.run("sqlite3 #{@db_name} 'UPDATE sqlite_sequence SET seq = 0'")
    end
  end
end
