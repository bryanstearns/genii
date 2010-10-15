class Features::Backup < Feature
  # Include something in the nightly backup
  attr_accessor :name, :configuration

  def create_dependencies
    depends_on :packages => { :name => "s3cmd" }

    depends_on :directory => {
                 :name => config_dir_path
               }

    depends_on :file => {
                 :name => "/usr/local/bin/nightlybackup",
                 :source => "backup/nightlybackup",
                 :mode => 0700
               }

#    depends_on :cron_job => {
#                 :login => :root,
#                 :command => "/backup/nightlybackup",
#                 :minutes => 5,
#                 :hours => 3,
#                 :context => find_feature(:rvm, :anything)
#               }

    depends_on :file => {
                 :name => "#{config_dir_path}/#{name}",
                 :content => backup_content,
                 :mode => 0644
               }
  end

  def config_dir_path
    "/etc/nightlybackup.d"
  end

  def backup_content
    # This is the file that tells nightlybackup what to do for this thing
    """# -----------------------------------------------------
# Backup: #{name}
# written by genii - DO NOT HAND EDIT!
# -----------------------------------------------------

#{configuration}
"""
  end
end
