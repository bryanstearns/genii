class Mediawiki < BackupItem
  # Backing up the mediawiki database and files
  attr_accessor :database, :user, :password

  def initialize(context, options)
    super
    @database ||= "wikidb"
    @root_dir ||= "/var/lib/mediawiki"
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
    abort "Backup of mediawiki database #{database} failed (#{$?}): #{output}" unless $? == 0
    log("Backed up mediawiki database: #{database}")

    # tar-up the filesystem too
    super
  end
end
