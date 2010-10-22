require 'optparse'
require 'yaml'

# RubyGems is only required for debugging
begin
  require 'rubygems'
  require 'ruby-debug'
rescue LoadError
  # ignore
end

def add_path(p)
  lib = File.expand_path(p)
  unless $LOAD_PATH.include?(lib)
    # puts "genii.rb: $LOAD_PATH << #{lib}"    
    $LOAD_PATH.unshift(lib)
  end
end
add_path(File.dirname(__FILE__) + "/genii")
require 'initializers'
require 'relative_path'

class Genii
  include Execute
  # Command-line flags and options
  attr_reader :dry_run, :verbose

  # Other state (accessible mostly for tests)
  attr_reader :configuration, :config_file

  def self.run!(*args)
    return self.new(*args).run
  end

  def initialize(*args)
    @start_time = Time.now.utc
    @verbose = 0
    @serve_port = 4443
    @args = args
    @config_file = "genii.yml"
    parse_args
  end

  def parse_args
    OptionParser.new do |opts|
      opts.banner = """genii - system installation from scratch

By default, shows what we'd install on this machine (as a long list of
feature details); use --apply to actually install.

Usage: genii [options]
"""

      opts.on("--as NAME", "Install features for this machine (instead of using hostname)") do |hostname|
        @hostname = hostname
        @dry_run = true
      end
      opts.on("--apply", "Actually install everything")\
        {|@apply|}
      opts.on("--all", "Check all features' generation, don't apply")\
        {|@all|}
      opts.on("--hierarchy", "Show me the hierarchy (instead of the list)")\
        {|@hierarchy|}
      opts.on("--serve", "Serve up a tarball for remote installation")\
        {|@serve|}
      opts.on("--dev", "  Serve a fresh tarball on each request")\
        {|@dev_mode|}
      opts.on("--proxied", "  Try to determine our public IP address")\
        {|@proxied|}
      opts.on("--config FILE", "Use this config file, instead of genii.yml")\
        {|@config_file|}
      opts.on("-v", "--verbose", "Blah blah blah") do
        @verbose += 1 unless @verbose >= Log::VERBOSITY_LEVELS.length
      end
      opts.on("--quiet", "No blah blah blah at all") do
        @verbose = -1
      end
      opts.on_tail("-h", "--help", "Show this message") do
        puts opts
        return 2
      end
    end.parse!(@args)
  end

  def run
    unless File.exist?(@config_file)
      STDERR.puts "Run genii from a project directory (that has '#{@config_file}' in it)!"
      return 1
    end

    setup_logging

    begin
      load_configuration
      if @serve
        serve_tarball
        return 3
      end
      add_load_paths

      if @all
        @configuration[:machines].keys.map(&:to_s).sort.each do |@hostname|
          @machine = nil
          log(:progress, "Checking #{@hostname}...")
          machine.features_to_install
        end
        log(:progress, "All machines good.")
      else
        feature_list = (@hierarchy ? describe_dependencies : describe_features)
        host = machine.name
        host += " (default)" if machine.class.name == "DefaultMachine"
        log(:progress, "On #{host}, will install these features:\n  " +
                       feature_list.join("\n  "))

        install_features if @apply
      end
      return 0
    rescue Exception => e
      STDERR.puts "#{e.message}\n#{e.backtrace[0].strip}"
      log(:noisy, "Exception: #{e.class}: #{e.message}\n\t#{e.backtrace.join("\n\t")}")
      return 1
    end
  end

  def setup_logging
    verbosity = @verbose == -1 \
     ? :never \
     : (VERBOSITY_LEVELS[@verbose] || :noisy)
    Log.add_logger(STDOUT, verbosity)
    if @apply or (@verbose > 0)
      log_path = '/var/log/genii.log'
      FileUtils.rm_rf(log_path)
      Log.add_logger(log_path, :noisy)
    end
    # VERBOSITY_LEVELS.each {|l| log(l, "This is level #{l}; verbosity is #{verbosity}") }
  end

  def serve_tarball
    # Run a webserver that serves up a tarball containing the project tree,
    # the gem contents, and a "genii" executable for installation on a
    # brand-new server

    # Set the window title so we know what this window's for
    puts("\033]0;#{`hostname`.strip}: genii\007") if STDOUT.isatty

    require 'webrick'
    require 'webrick/https'
    require 'stringio'
    require 'openssl'
    require 'net/http'
    Socket.do_not_reverse_lookup = true # speed things up

    server_config = @configuration[:serve] || {}
    server_config[:user] ||= 'genii'
    server_config[:password] ||= 'genii'

    # Creating the server creates a self-signed SSL cert, which is noisy
    # on stderr - silence it.
    $stderr = IOSwitch.new($stderr)
    server = $stderr.silenced do
      WEBrick::HTTPServer.new(:Port => @serve_port,
                              :BindAddress => "0.0.0.0",
                              :SSLEnable => true,
                              :SSLVerifyClient => OpenSSL::SSL::VERIFY_NONE,
                              :SSLCertName => [["C", "US"],
                                               ["O", `hostname`.strip],
                                               ["CN", "WWW"]])
    end

    puts """genii for:
   #{@configuration[:machines].keys.map{|k| k.to_s}.sort.join("\n   ")}

Do something like:
   curl https://#{accessible_machine_name}:#{@serve_port}/genii -ku #{server_config[:user]}:#{server_config[:password]} | tar xzf -
   cd genii
   sudo ./genii --apply

"""

    make_tarball unless @dev_mode

    authenticate = Proc.new do |request, response|
      WEBrick::HTTPAuth.basic_auth(request, response, '') do |user, password|
        user == server_config[:user] && password == server_config[:password]
      end
    end
    server.mount_proc('/genii') do |request, response|
      begin
        authenticate.call(request, response)
        tarball = make_tarball
        response['content-length'] = tarball.size
        response['content-type'] = 'application/x-tar'
        response['content-disposition'] = 'filename=genii.tgz'
        response.body = tarball
        discard_tarball if @dev_mode
      end
    end
    [@configuration[:secrets]].flatten.compact.each do |dir|
      server.mount("/#{dir}", WEBrick::HTTPServlet::FileHandler,
                   File.expand_path(dir),
                   :HandlerCallback => authenticate)
    end
    ['INT', 'TERM'].each {|signal| trap(signal) { server.shutdown } }
    server.start
  end

  def make_tarball
    # Build a tarball containing the project tree, the gem contents, and
    # a "genii" executable for installation on a brand-new server
    @tarball ||= begin
      tar_dir = "/tmp/genii.tar.#{$$}"
      begin
        dont_serve = %w[.git]
        dont_serve += @configuration[:secrets] if @configuration[:secrets]
        dont_serve += @configuration[:do_not_serve] if @configuration[:do_not_serve]
        excludes = dont_serve.map{|x| "--exclude #{x}"}.join(' ')
        source_dir = Dir.getwd
        gem_dir = File.expand_path(File.dirname(__FILE__) + "/..")
        ball_dir = "#{tar_dir}/genii"
        FileUtils.mkdir_p(ball_dir)
        execute([
          "cp -R #{source_dir}/* #{ball_dir}",
          "cp -R #{gem_dir} #{ball_dir}/gem",
          "cp -f #{@config_file} #{ball_dir}/genii.yml",
          "echo \"#!/bin/sh\nsudo gem/bin/genii \\$*\" >#{ball_dir}/genii",
          "chmod +x #{ball_dir}/genii"
        ].join(" && "))
        tar_cmd = "tar czf - #{excludes} genii"
        execute(tar_cmd, :binary => true, :cwd => tar_dir).output
      ensure
        FileUtils.rm_rf(tar_dir)
      end
    end
  end

  def discard_tarball
    @tarball = nil
  end

  def load_configuration
    @configuration = {}
    def files
      yield @config_file
      [@configuration[:additional_configuration]].flatten.compact.each do |f|
        yield f
      end
    end
    def load_file(path)
      if File.exist?(path)
        log(:details, "Reading configuration from #{path}")
        File.open(path) {|f| YAML::load(f).symbolize_keys }
      else
        log(:details, "Skipping non-existant configuration file #{path}")
        {}
      end
    end
    files do |path|
      more_config = load_file(path)
      more_config[:machines].each do |machine, config|
        more_config[:machines][machine] = { :machine => config } \
          unless config.is_a? Hash
      end if more_config[:machines]
      @configuration.deep_merge!(more_config)
    end
    log(:details, "Configuration:\n#{@configuration.to_yaml}")
  end

  def add_load_paths
    add_path(File.dirname(__FILE__) + "/genii/features")
    add_path("./features") if File.directory?("./features")
    more = [@configuration[:additional_paths]].flatten.compact
    more.each {|p| add_path(p) }
  end

  def describe_features
    machine.features_to_install.map {|feature| describe_feature(feature) }
  end

  def describe_feature(feature, seen=false, depth=0)
    doneFlag = if seen
      '-'
    elsif feature.done?
      '✔'
    else
      '.'
    end
    object_info = " (0x#{feature.object_id.to_s(16)})" if @verbose > 1
    "#{'  ' * depth}#{doneFlag} #{feature.describe}#{object_info}"
  end

  def describe_dependencies
    seen = Set.new
    machine.feature_hierarchy.map do |depth, feature|
      description = describe_feature(feature, seen.include?(feature), depth)
      seen << feature
      description
    end
  end

  def install_features
    machine.install_features

    seconds = (Time.now.utc - @start_time).to_i
    duration = [3600, 60, 1].map do |d|
      result = seconds / d
      seconds = seconds % d
      sprintf("%02d", result)
    end.join(':')
    log(:progress, "Done in #{duration}")
  end

  def machine
    @machine ||= begin
      hostname = @hostname || `hostname`.strip
      machine_settings = @configuration[:machines][hostname.to_sym]
      machine_settings ||= :default
      role = machine_settings[:machine] || hostname
      @configuration.deep_merge!(@configuration[:settings])\
        if @configuration[:settings]
      @configuration.deep_merge!(machine_settings)
      @configuration[:hostname] = hostname.to_s
      log(:details, "Using role \"#{role}\" for \"#{hostname}\"; " +
                    "full configuration:\n#{@configuration.inspect}")
      Machine.load(role, @configuration)
    end
  end

  def accessible_machine_name
    begin
      @proxied && Net::HTTP.get("whatismyipaddress.com", '/') =~ \
                    /name="LOOKUPADDRESS" value="([^\"]+)"/ && $1
    rescue
      nil
    end || `hostname`.strip
  end
end

class IOSwitch
  # Wrap an IO object so we can silence it
  attr_accessor :on, :io
  def initialize(io, on=true)
    @io = io
    @on = on
  end
  def read(*args)
    @io.read(*args)
  end
  %w[write putc <<].each do |method|
    define_method(method) do |*args|
      @io.send(method, *args) if @on
    end
  end
  def silenced
    old, @on = [@on, nil]
    begin
      yield
    ensure
      @on = old
    end
  end
end
