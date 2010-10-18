class Features::Service < Feature
  attr_accessor :name, :use_initd, :start_command,
                :status_command, :stop_command

  # A few services we know don't use Upstart yet
  NON_UPSTART_SERVICES = %w[apache2 exim4 monit ssh ganglia-monitor gmetad]
  NO_STATUS_SERVICES = %w[monit]

  def initialize(options={})
    super(options)
    self.use_initd ||= NON_UPSTART_SERVICES.include? name.to_s
    if use_initd
      self.start_command ||= "/etc/init.d/#{name} start"
      if status_command == false or NO_STATUS_SERVICES.include?(name.to_s)
        self.status_command = nil
      else
        self.status_command ||= "/etc/init.d/#{name} status"
      end
      self.stop_command ||= "/etc/init.d/#{name} stop"
    else
      self.start_command ||= "start #{name}"
      if status_command == false
        self.status_command = nil
      else
        self.status_command ||= "status #{name}"
      end
      self.stop_command ||= "stop #{name}"
    end
  end

  def done?
    false
  end

  def apply
    restart!
  end

  def restart!
    log(:progress, "Before restarting service #{name}, status is:\n#{execute(status_command, :ignore_error => true).output}") \
      unless status_command.nil?
    log(:progress, "Stopping service #{name}")
    stop_cmd = execute(stop_command, :ignore_error => true)
    log(:progress, "Restart failed:\n#{stop_cmd.output_message}\n... starting anyway...") \
      unless stop_cmd.success?
    sleep(2)
    log(:progress, "Starting service #{name}")
    execute(start_command)
    log(:progress, "Start succeeded.")
  end
end
