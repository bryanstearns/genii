class Logfiles < BackupItem
  # Backup and archiving of logs from /var/log (or elsewhere)
  # the name is the basename of the logfile, eg "syslog" or "paydici.log"; the assumption is
  # that logrotate will add a date-stamped suffix to the log on the first rotation, and gzip 
  # after that.
  #
  # The log of this name, with or without a date-stamped suffix, will be compressed, encrypted, 
  # and backed up to S3
  #
  # Any logs with a date-stamp and gzip suffix will be encrypted and copied to S3
  # if not already there; any of those already there older than 14 days will be removed
  
  attr_accessor :dir, :purge_after_days, :log_names
  
  def initialize(context, options)
    rails_app_dir = options.delete("rails_app_dir")
    if rails_app_dir
      rails_env = options.delete("rails_env", "backup")
      options["database"], options["user"], options["password"] = \
        parse_database_yml(rails_app_dir, rails_env)
    end
    super
    @dir ||= '/var/log'
    @purge_after_days ||= 14
  end

  def run
    log_names.each do |log_name|
      run_one_log(log_name)
    end
  end

  def run_one_log(log_name)
    Dir.glob("#{dir}/#{log_name}*").sort.each do |log_path|
      log_file = File.basename(log_path)
      if log_file =~ /(\d{8})\.gz$/
        # Make sure this log exists on S3...
        unless @context.skip_s3
          date = Regexp.last_match(1)
          result_file = "#{log_file}.enc" # has .gz in name already
          if !@context.s3_bucket_contains?("logfiles", result_file)
            tf = Tempfile.new(log_file)
            begin
              tf.close
              encrypt(log_path, tf.path)
              @context.s3_bucket_add("logfiles", tf.path, :name => result_file)
            ensure
              tf.unlink
            end
          elsif !@context.skip_cleanup
            # Delete the local copy if it's old enough
            date = Date.civil(date[0..3].to_i, date[4..5].to_i, date[6..7].to_i) rescue nil
            age = date && (Date.today - date)
            if age and age > purge_after_days
              log("Deleting #{log_path}")
              FileUtils.rm(log_path)
            end
          end
        end
      elsif log_file !~ /\.gz$/
        compress_and_encrypt(log_path,
          File.join(@context.latest_dir, "#{log_file}.gz.enc"))
      else
        log("Skipping gzipped logfile with a non-datestampped name: #{log_path}")
      end
    end
  end

  def encrypt(in_path, out_path)
    cmd = @context.encrypt_command(:in => in_path, :out => out_path)
    log(cmd) if verbose
    output = execute(cmd)
    abort "Backup of #{in_path} failed (#{$?}): #{output}" unless $? == 0
    log("Backed up #{in_path}")
  end

  def compress_and_encrypt(in_path, out_path)
    cmd = [
      "gzip <#{in_path}",
      @context.encrypt_command(:out => out_path)
    ].join(" | ")
    log(cmd) if verbose
    output = execute(cmd)
    abort "Backup of #{in_path} failed (#{$?}): #{output}" unless $? == 0
    log("Backed up #{in_path}")
  end
end
