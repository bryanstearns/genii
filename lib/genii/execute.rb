module Execute
  class Execute::Error < StandardError; end

  class ShellCommand
    # Execute a command in a subshell

    include Enumerable

    # These are the expected options:
    attr_accessor :cwd, :binary, :ignore_error, :quiet, :verbose,
                  :no_redirection, :context, :retry_on_failure
    
    # Other accessors:
    attr_accessor :command, :full_command, :output_message, :status, :output

    def initialize(command, options={})
      options.each {|k,v| send("#{k}=", v)}
      self.command = command
    end

    def command=(new_command)
      @command = @full_command = new_command

      if context
        @full_command = if context.respond_to? :wrap_command
          context.wrap_command(@full_command)
        else
          context.call(@full_command)
        end
      end

      @full_command = "#{@full_command} 2>&1" \
        unless (binary || no_redirection)

      @full_command = "#{@full_command} >/dev/null" \
        if quiet && !binary

      @command
    end

    def run
      log(:detail, "execute: '#{full_command}'")
      if cwd
        FileUtils.cd(cwd) do
          run_raw
        end
      else
        run_raw
      end
      lines.each {|line| yield line } if block_given?
      self
    end

    def success?
      status == 0
    end

    def to_s
      output
    end

    def each
      output.split("\n").each {|line| yield line }
    end

    def output_message
      msg = []
      msg << "Execution_failed: " if status != 0
      msg << "`#{full_command.inspect}` returned #{status}"
      msg << (binary ? " (#{output.length} bytes)" : "\n#{output}")
      msg.join
    end

  private
    def run_raw
      begin
        begin
          self.output = `#{full_command}`
        rescue Exception
          STDERR.puts "While executing '#{full_command}'..."
          raise
        end
        self.output = output.rstrip unless binary
        self.status = $? >> 8
        if status != 0 && retry_on_failure
          log(:progress, "Failed (#{status}); waiting to try again")
          sleep((retry_on_failure == true) ? 10 : retry_on_failure)
        end
      end while (status != 0) && retry_on_failure
      
      if status != 0
        if !ignore_error
          log(:noisy, output_message)
          raise Execute::Error.new(output_message)
        end
      else
        log(:debug, output_message)
      end
    end
  end

  def execute(command, options={}, &block)
    ShellCommand.new(command, options).run(&block)
  end
end
