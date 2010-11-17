class Features::CronJob < Feature
  # Add a crontab entry for a user
  attr_accessor :login, :command, :minutes, :hours, :days_of_month,
                :months, :days_of_week, :context

  def initialize(options={})
    options[:minutes] ||= options.delete(:minute)
    options[:hours] ||= options.delete(:hour)
    options[:days_of_month] ||= options.delete(:days_of_month)
    options[:months] ||= options.delete(:month)
    options[:days_of_week] ||= options.delete(:days_of_week)
    super(options)
    abort("cron_job requires :login (#{options.inspect})") unless login
    abort("cron_job requires :command (#{options.inspect})") unless command
  end

  def done?
    # This could mean any number of things, all of which map to "not done" :-)
    cmd = full_command
    cmd && parse_crontab[cmd]
  end

  def apply
    Features::CronJob.add(options)
  end

  def describe_options
    # Shorten the context if we were given one
    result = options.dup
    result[:context] &&= (result[:context].name rescue result[:context].class.name)
    result
  end

  def self.add(options)
    # Do all the work to add (or replace) a cronjob
    # (this is static, so other recipes can call it directly)
    login = options[:login]
    entries = parse_crontab(login)
    log(:error, "Entries is #{entries.inspect}")
    cmd = self.full_command(options[:command], options[:context])
    abort "oops, can't determine full command at apply time!" unless cmd
    entries[cmd] = [
      options[:minutes] || "*",
      options[:hours] || "*",
      options[:days_of_month] || "*",
      options[:months] || "*",
      options[:days_of_week] || "*"
    ].join(' ')
    write_crontab(entries, login)
  end

private
  def full_command
    Features::CronJob.full_command(command, context)
  end
  def self.full_command(command, context)
    # Either use the command we were given, or, if given a context, wrap it
    return command unless context
    return nil unless context.done?
    context.wrap_command(command)
  end

  def parse_crontab
    @parsed_crontab ||= Features::CronJob.parse_crontab(login)
  end
  def self.parse_crontab(login)
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

  def write_crontab(entries)
    Features::CronJob.write_crontab(entries, login)
    @parsed_crontab = nil
  end
  def self.write_crontab(entries, login)
    temp_file = "/tmp/genii.crontab.#{Process.pid}"
    begin
      crontab_content = entries.map do |command, schedule|
        "#{schedule} #{command}"
      end.join("\n")
      FU.write!(temp_file, crontab_content)
      execute("crontab -u #{login} #{temp_file}")
    ensure
      FileUtils.rm_f(temp_file)
    end
  end
end
