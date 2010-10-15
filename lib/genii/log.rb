require 'logger'

module Log
  # We use our own logging levels
  LEVEL_MAPPING = {
    :noisy => "DEBUG",
    :debug => "INFO",
    :detail => "WARN",
    :progress => "ERROR",
    :error => "FATAL",
    :never => nil
  }
  REVERSE_LEVEL_MAPPING = LEVEL_MAPPING.invert
  VERBOSITY_LEVELS = [:progress, :detail, :debug, :noisy]

  def add_logger(target, level)
    @@loggers ||= []
    @@loggers << begin
      new_logger = Logger.new(target)
      new_logger.level = Logger.const_get(LEVEL_MAPPING[level])

      # Use our formatter
      new_logger.formatter = if target.try(:isatty)
        Proc.new do |severity, datetime, progname, msg|
          "#{colorize(severity, datetime.strftime("%y-%m-%d %H:%M:%S"))} #{msg}\n"
        end
      else
        Proc.new do |severity, datetime, progname, msg|
          "#{datetime.strftime("%y-%m-%d %H:%M:%S")} #{msg}\n"
        end
      end
      new_logger
    end
  end

  def log(severity, message=nil, &block)
    severity = Logger.const_get(LEVEL_MAPPING[severity] || return)
    loggers.each {|logger| logger.log(severity, message, &block) }
  end

  def show_levels
    LEVEL_MAPPING.keys.each {|x| log(x, "This is #{x}") }
  end

  LEVEL_MAPPING.keys.each do |level|
    define_method("log_#{level}?") do
      loggers.any? {|logger| logger.send("#{LEVEL_MAPPING[level].downcase}?") }
    end
  end

private
  def loggers
    @@loggers ||= []
    @@loggers
  end

  def colorize(severity, text)
    # http://github.com/flori/term-ansicolor/blob/master/lib/term/ansicolor.rb
    color = case REVERSE_LEVEL_MAPPING[severity]
    when :noisy
      36 # cyan
    when :debug
      33 # yellow
    when :detail
      2 # dark
    when :progress
      32 # green
    when :error
      31 # red
    else
      return text
    end
    "\e[#{color}m#{text}\e[0m"
  end
end
