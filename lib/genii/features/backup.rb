class Features::Backup < Feature
  # One instance should set these global parameters
  attr_accessor :backup_dir, :s3_config_path, :encryption_key_path

  # Others just use these to include something in the nightly backup
  attr_accessor :name, :comment, :configuration

  # Backup:
  # A bunch of things contribute to it:
  # - database backups
  # - system, apache, rails logs
  # - RRD databases
  # - 
  # each contribution is
  # - tarred
  # - (optionally) encrypted
  # - (optionally) copied to a date-stamped S3 bucket

  def create_dependencies
    depends_on :packages => { :name => "s3cmd" }

    depends_on :directory => {
                 :name => config_dir_path
               }

    depends_on :file => {
                 :name => "/etc/nightlybackup/nightlybackup.yml",
                 :content => nightlybackup_yml_content,
                 :mode => 0600
               }

    depends_on(:file => {
                 :name => encryption_key_path_on_target,
                 :source => encryption_key_path
               })\
      if encryption_key_path

    depends_on :file => {
                 :name => "/usr/local/bin/nightlybackup",
                 :source => "backup/nightlybackup",
                 :mode => 0755
               }

#    depends_on :cron_job => {
#                 :login => :root,
#                 :command => "/usr/local/bin/nightlybackup",
#                 :minutes => 5,
#                 :hours => 3,
#                 :context => find_feature(:rvm, :anything)
#               }

    depends_on(:file => {
                 :name => "#{config_dir_path}/#{name}",
                 :content => backup_content,
                 :mode => 0644
               })\
      if name
  end

  def config_dir_path
    "/etc/nightlybackup/conf.d"
  end

  def encryption_key_path_on_target
    File.join("/etc/nightlybackup", File.basename(encryption_key_path))
  end

  def backup_content
    # This is the file that tells nightlybackup what to do for this thing
    [genii_header("Backup: #{name}"),
     comment && "# #{comment}",
     configuration.is_a?(Hash) ? configuration.to_yaml : configuration
    ].compact.join("\n")
  end

  def nightlybackup_yml_content
    # This is the global config file for nightlybackup
    """#{genii_header("Nightly backup settings")}

# Where to accumulate backups
#{backup_dir_setting}

# Key to encrypt backup files
#{encryption_key_path_setting}

# Copying to Amazon S3
#{s3_settings}
"""
  end

  def backup_dir_setting
    if backup_dir
      "backup_dir: #{backup_dir}"
    else
      "# backup_dir: /var/spool/backup_snapshots (default)"
    end
  end

  def encryption_key_path_setting
    if encryption_key_path
      "encryption_key_path: #{encryption_key_path_on_target}"
    else
      "# encryption_key_path: ... (no encryption by default!)"
    end
  end

  def s3_settings
    if s3_config_path
      s3_secrets = File.open(RelativePath.find(s3_config_path)) \
        {|f| YAML::load(f) }
      [
        "s3_access_key_id: #{s3_secrets['access_key_id']}",
        "s3_secret_access_key: #{s3_secrets['secret_access_key']}"
      ]
    else
      [
        "# s3_access_key_id: ... (no copy to S3 by default)",
        "# s3_secret_access_key: ..."
      ]
    end.join("\n")
  end
end
