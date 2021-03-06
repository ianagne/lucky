require "lucky_cli"
require "option_parser"
require "colorize"

# Based on the sentry shard with some modifications to outut and build process.
module Sentry
  FILE_TIMESTAMPS = {} of String => String # {file => timestamp}

  class ProcessRunner
    include LuckyCli::TextHelpers

    getter app_processes = [] of Process
    property successful_compilations
    property app_built

    @app_built : Bool = false
    @successful_compilations : Int32 = 0

    def initialize(build_commands : Array(String), run_commands : Array(String), files : Array(String))
      @build_commands = build_commands
      @run_commands = run_commands
      @files = files
    end

    private def build_app_processes
      @build_commands.map do |command|
        Process.run(command, shell: true, output: true, error: true)
      end
    end

    private def create_app_processes
      @app_processes.clear
      result = @run_commands.each do |command|
        @app_processes << Process.new(command, shell: false, output: true, error: true)
      end

      self.successful_compilations += 1
      if successful_compilations == 1
        start_browsersync
      else
        reload_browsersync
      end
    end

    private def start_browsersync
      spawn do
        Process.run "yarn run browser-sync start -c bs-config.js --port #{browsersync_port} -p #{proxy}",
          output: true,
          error: true,
          shell: true
      end
    end

    private def proxy
      "http://#{Lucky::Server.settings.host}:#{Lucky::Server.settings.port}"
    end

    private def reload_browsersync
      Process.run "yarn run browser-sync reload --port #{browsersync_port}",
        output: true,
        error: true,
        shell: true
    end

    private def browsersync_port
      3001
    end

    private def get_timestamp(file : String)
      File.stat(file).mtime.to_s("%Y%m%d%H%M%S")
    end

    def start_app
      stop_all_processes
      puts "compiling..."
      start_all_processes
    end

    private def stop_all_processes
      @app_processes.each do |process|
        process.kill unless process.terminated?
      end
    end

    private def start_all_processes
      if build_app_processes.all? &.success?
        self.app_built = true
        create_app_processes()
      elsif !app_built
        print_error_message
      end
    end

    private def print_error_message
      puts "There was a problem compiling. Watching for fixes...".colorize(:red)
      if successful_compilations.zero?
        puts <<-ERROR

        Try this...

          #{green_arrow} If you haven't done it already, run #{"bin/setup".colorize(:green)}
          #{green_arrow} Run #{"shards install".colorize(:green)} to ensure dependencies are installed
          #{green_arrow} Ask for help in #{"https://gitter.im/luckyframework/Lobby".colorize(:green)}
        ERROR
      end
    end

    def scan_files
      file_changed = false
      app_processes = @app_processes
      files = @files
      Dir.glob(files) do |file|
        timestamp = get_timestamp(file)
        if FILE_TIMESTAMPS[file]? && FILE_TIMESTAMPS[file] != timestamp
          FILE_TIMESTAMPS[file] = timestamp
          file_changed = true
          puts "#{file} has changed".colorize(:yellow)
        elsif FILE_TIMESTAMPS[file]?.nil?
          FILE_TIMESTAMPS[file] = timestamp
          file_changed = true if (app_processes.none? &.terminated?)
        end
      end

      start_app() if file_changed # (file_changed || app_processes.empty?)
    end
  end
end

class Watch < LuckyCli::Task
  banner "Start and recompile project when files change"

  def call
    build_commands = ["crystal build ./src/server.cr"]
    run_commands = ["./server"]
    files = ["./src/**/*.cr", "./src/**/*.ecr", "./config/**/*.cr", "./shard.lock"]

    process_runner = Sentry::ProcessRunner.new(
      files: files,
      build_commands: build_commands,
      run_commands: run_commands
    )

    puts "Beginnning to watch your project"

    loop do
      process_runner.scan_files
      sleep 0.1
    end
  end
end
