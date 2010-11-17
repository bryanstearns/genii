class Feature
  include Execute
  extend Execute # so that class methods can execute too!
  include Git

  attr_accessor :options
  attr_reader :nothing_else_to_do

  def initialize(options={})
    self.options = options
    options.each {|k,v| send("#{k}=", v)}
  end

  def describe
    class_name = self.class.name
    split_name = class_name.split('::')
    class_name = split_name.last if split_name.first == "Features"
    [class_name, option_descriptions].compact.join(' ')
  end

  def describe_options
    options
  end

  def option_descriptions
    options_to_describe = describe_options
    return nil unless options_to_describe && !options_to_describe.empty?
    
    options_to_describe.map do |pair|
      k, v = *pair
      k = k.to_s
      if k =~ /mode$/ && v.is_a?(Numeric)
        v = "0#{v.to_s(8)}"
      end
      "#{k}=#{v.inspect}"
    end.join(', ')
  end

  def create_dependencies
    # Nothing by default
  end

  def dependencies
    # A (shallow) list of the features this feature depend on
    @dependencies ||= []
  end

  def dependencies_after
    # A (shallow) list of the features this feature depends on, but which
    # must be installed *after* this feature.
    @dependencies_after ||= []
  end

  def depends_on(feature_def, dependency_options={})
    # for example:
    #   depends_on :directory => {
    #                :name => '/etc/foo',
    #                :dir_mode => 0755,
    #              }
    #   depends_on :file => {
    #                :name => "/etc/foo/bar",
    #                :mode => 0644,
    #                :owner => :root,
    #              }
    #   depends_on :rvm
    # To add a dependency that should occur after another feature,
    # specify eg:
    #   depends_on :file => {
    #                ...
    #              }, :do_after => machine.find_feature(:rvm, :anything)
    # (The other feature has to already have been declared; also,
    #  if something earlier already depends on this file, it will have been
    #  handled already anyway)
    do_after = nil
    class_symbol, options = case feature_def
    when Symbol
      [feature_def, {}]
    when Hash
      do_after = feature_def.delete(:do_after) 
      [feature_def.keys.first, feature_def.values.first]
    else
      abort "Can't understand dependency: #{feature_def.inspect}"
    end

    feature = machine.find_or_create_feature(class_symbol, options)
    do_after ||= dependency_options[:do_after]
    if do_after
      do_after.dependencies_after << feature
    else
      dependencies << feature
    end
    feature
  end

  def requires(class_symbol=nil, options={}, &block)
    # Express a dependency on an already-created feature using a subset of
    # its options
    feature = find_feature(class_symbol, :with => options, &block)

    abort "Required feature not found: #{class_symbol} with #{options.inspect}" \
      unless feature
    feature
  end

  def find_feature(class_symbol=nil, options={}, &block)
    # Find an already-created feature with these characteristics
    machine.find_feature(class_symbol, options, &block)
  end

  def matches(class_symbol=nil, options={}, &block)
    return yield(self) if block_given?

    return false unless self.class.name.split('::').last \
                     == class_symbol.to_s.classify

    return true if options == :anything

    if options.keys == [:with] and options[:only].is_a? Hash
      # We're only matching these options
      options.all? {|k, v| self.options[k] == v }
    else
      # all have to match
      self.options == options
    end
  end

  def machine
    Machine.current
  end

  def configuration
    machine.configuration
  end

  def checklist(message)
    machine.checklist(message)
  end

  def find_machine(role)
    role = role.to_s
    configuration[:machines].each do |machine, configuration|
      return machine if configuration[:machine] == role
    end
    nil
  end

  def locate_file(subpath, &block)
    machine.locate_file(subpath, &block)
  end

  def walk(depth_first=true, depth=0, &block)
    depth_self = [depth, self]
    yield depth_self unless depth_first
    dependencies.each do |dependency|
      dependency.walk(depth_first, depth+1, &block)
    end
    yield depth_self if depth_first
    dependencies_after.each do |dependency|
      dependency.walk(depth_first, depth+1, &block)
    end
  end

  def features(depth_first=true)
    results = []
    walk(depth_first) do |depth_ignored, feature|
      results << feature if !block_given? or yield(feature)
    end
    results
  end

  def feature_hierarchy
    results = []
    walk(false) do |depth, feature|
      results << [depth, feature] if !block_given? or yield(feature)
    end
    results
  end

  def apply
  end

  def done?
    !@nothing_else_to_do
  end

  def nothing_else_to_do!
    # Set a flag that says this feature doesn't do anything but act as a
    # parent for other things.
    @nothing_else_to_do = true
  end

  def genii_header(msg)
    lines = msg.split("\n")
    genii_msg = "written by genii; DO NOT HAND EDIT"
    lines = if lines[0].length > (75 - genii_msg.length)
      [lines[0], genii_msg, lines[1..-1]]
    else
      [lines[0] + " - " + genii_msg, lines[1..-1]]
    end.flatten
    border = "-" * lines.map(&:length).max
    lines.unshift(border)
    lines << border
    lines.map{|l| "# #{l}" }.join("\n") + "\n"
  end
end
