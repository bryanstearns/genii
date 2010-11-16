class MysqlDatabase < BackupItem
  # Database access parameters
  attr_accessor :database, :user, :password

  def name
    database
  end

  def initialize(context, options)
    rails_app_dir = options.delete("rails_app_dir")
    if rails_app_dir
      rails_env = options.delete("rails_env", "backup")
      options["database"], options["user"], options["password"] = \
        parse_database_yml(rails_app_dir, rails_env)
    end
    super
  end

  def run
    # Dump the database, compressed & encrypted
    cmd = [
      @context.database_dump_command(database, user, password),
      'gzip',
      @context.encrypt_command(:out => pathname(".sql.gz.enc"))
    ].join(' | ')
    log(cmd)
    output = execute(cmd)
    abort "Backup of database #{database} failed (#{$?}): #{output}" unless $? == 0
    log("Backed up database: #{database}")
  end

  def parse_database_yml(rails_app_dir, rails_env)
    db_yml = load_yaml(File.join(rails_app_dir, "config", "database.yml"))
    config = db_yml[rails_env]
    [config["database"], config["user"], config["password"]]
  end
end
