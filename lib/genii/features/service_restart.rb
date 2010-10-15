class Features::ServiceRestart < Feature
  attr_accessor :name, :uniquifier

  def initialize(options={})
    @@restart_index ||= 0
    @@restart_index += 1
    options[:uniquifier] = @@restart_index
    super(options)
    abort("Can't find service named '#{options[:name]}'")\
      unless find_service
  end

  def done?
    false
  end

  def apply
    find_service.restart!
  end


  def describe_options
    result = options.dup
    result.delete(:uniquifier)  # Don't need to show this
    result
  end

private
  def find_service
    find_feature(:service, :name => name)
  end
end