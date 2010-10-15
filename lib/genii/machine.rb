require 'set'
require 'socket'


class Machine < Feature
  attr_reader :name, :configuration, :all_features

  def self.load(name, configuration)
    # Given a hostname, find a Machine object to use to set it up.
    # Can't find one by that name? Use the default one.
    @current_machine = begin
      "#{name.to_s.classify}Machine".constantize.new(name, configuration)
    rescue LoadError, NameError
      begin
        DefaultMachine.new(name, configuration)
        log(:progress, "No machine defined for #{name}; using DefaultMachine")
      rescue LoadError, NameError
        abort "No machine defined for #{name}, and no DefaultMachine"
      end
    end
    @current_machine.create_dependencies
    @current_machine.nothing_else_to_do!
    @current_machine
  end

  def self.current
    @current_machine
  end

  def initialize(name, configuration)
    @name = name
    @all_features = []
    @configuration = configuration
  end

  def create_dependencies
    # Useless default is "no dependencies"; subclasses will override.
  end

  def architecture
    @architecture ||= execute("uname -m").output
  end

  def find_or_create_feature(klass, options)
    find_feature(klass, options) || create_feature(klass, options)
  end

  def find_feature(class_symbol=nil, options={}, &block)
    all_features.each do |feature|
      return feature if feature.matches(class_symbol, options, &block)
    end
    nil
  end

  def find_file_in_load_path(subpath)
    return subpath if subpath[0..0] == "/" # absolute paths returned as-is

    $LOAD_PATH.each do |dir|
      path = File.join(dir, subpath)
      return File.expand_path(path) if File.exist?(path)
    end
    nil
  end

  def locate_file(subpath)
    # Find a file relative to anywhere in our load path
    # and either yield an IO object to it, or read its contents
    result = find_file_in_load_path(subpath)
    if result
      if block_given?
        File.open(result, 'r') {|f| yield f }
        return nil
      else
        return IO.read(result)
      end
    end

    # Not here; ask the server
    # TODO
    raise Errno::ENOENT, "Not found locally or on server - #{subpath}"
  end

  def create_feature(class_symbol, options)
    class_name = class_symbol.to_s
    klass = begin
      "Features::#{class_name.classify}".constantize
    rescue NameError, LoadError
      class_name.classify.constantize
    end
    feature = klass.new(options)
    all_features << feature
    feature.create_dependencies
    feature
  end

  def features_to_install
    seen = Set.new
    features do |feature|
      if seen.include?(feature)
        false
      else
        seen << feature
        true
      end
    end
  end

  def install_features
    features_to_install.each do |feature|
      if feature.done?
        log(:progress, "#{feature.describe}: nothing#{' else' if feature.nothing_else_to_do} to do")
      else
        log(:progress, "#{feature.describe}: applying")
        feature.apply
      end
    end
  end

  def describe
    "Machine name=\"#{name}\"#{' (default)' if self.class.name == 'DefaultMachine'}"
  end

  def local_ip
    @local_ip ||= begin
      # Get my local IP address
      # see: http://coderrr.wordpress.com/2008/05/28/get-your-local-ip-address/
      # Turn off reverse DNS resolution temporarily
      orig, Socket.do_not_reverse_lookup = Socket.do_not_reverse_lookup, true
      UDPSocket.open do |s|
        # This address happens to be google's, but we don't actually talk to it:
        # UDP doesn't actually connect on 'connect'
        s.connect '8.8.8.8', 1
        s.addr.last
      end
    ensure
      Socket.do_not_reverse_lookup = orig
    end
  end
end
