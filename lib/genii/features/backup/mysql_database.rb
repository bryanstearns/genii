class MysqlDatabase < BackupItem
  # Database access parameters
  attr_accessor :database, :user, :password

  def name
    database
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
end
