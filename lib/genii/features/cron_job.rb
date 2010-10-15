class Features::CronJob < Feature
  # Add a crontab entry for a user
  attr_accessor :login, :command, :minutes, :hours, :days_of_month,
                :months, :days_of_week, :context

  def initialize(options={})
    options[:minutes] ||= options.delete(:minute)
    options[:hours] ||= options.delete(:hour)
    options[:days_of_month] ||= options.delete(:day_of_month)
    options[:months] ||= options.delete(:month)
    options[:days_of_week] ||= options.delete(:day_of_week)
    super(options)
    abort("cron_job requires :login (#{options.inspect})") unless login
    abort("cron_job requires :command (#{options.inspect})") unless command

    self.minutes ||= "*"
    self.hours ||= "*"
    self.days_of_month ||= "*"
    self.months ||= "*"
    self.days_of_week ||= "*"
  end

  def done?
    # This could mean any number of things, all of which map to "not done" :-)
    cmd = full_command
    cmd && parse_crontab[cmd]
  end

  def apply
    entries = parse_crontab
    log(:error, "Entries is #{entries.inspect}")
    cmd = full_command
    abort "oops, can't determine full command at apply time!" unless cmd
    entries[full_command] = \
      [minutes, hours, days_of_month, months, days_of_week].join(' ')
    write_crontab(entries)
  end

  def describe_options
    # Shorten the context if we were given one
    result = options.dup
    result[:context] &&= result[:context].name
    result
  end

private
  def full_command
    # Either use the command we were given, or, if given a context,
    # wrap it
    return command unless context
    return nil unless context.done?
    context.wrap_command(command)
  end

  def parse_crontab
    @parsed_crontab ||= begin
      cmd = execute("crontab -u #{login} -l", :ignore_error => true)
      if cmd.success?
        log(:error, "crontab read, got:\n#{cmd.output}")
        cmd.output.split("\n").inject({}) do |h, line|
          if /(\S+\s+\S+\s+\S+\s+\S+\s+\S+)\s+(.*)$/.match(line)
            h[$2] = $1
          end
          h
        end
      else
        log(:debug, "crontab parse returned #{cmd.status}, said \"#{cmd.output}\"")
        {}
      end
    end
  end

  def write_crontab(entries)
    temp_file = "/tmp/genii.crontab"
    File.open(temp_file, 'w') do |f|
      entries.each do |command, schedule|
        f.write("#{schedule} #{command}\n")
      end
    end
    execute("crontab -u #{login} #{temp_file}")
    FileUtils.rm_f(temp_file)
    @parsed_crontab = nil
  end
end
