require 'yaml'

class Features::RailsAppInstance < Feature
  include SiteInfo
  
  # Whew, whole lotta options... In addition to SiteInfo's, which
  # we pass along to our ApacheApplication, there are:
  
  # - The Rails environment in which the app runs
  # - The Rails gem version
  attr_accessor :environment, :rails_version
  # - The git URL, and the branch we'll check out, and a flag that
  #   will cause us to set up submodules (defaults off)
  attr_accessor :repository_url, :repository_branch, :enable_submodules
  # - Database config for this instance:
  #   - if :none, we won't use one
  #   - if {:slave => xxx}, we'll assume it exists (a connection to
  #     another machine's existing database)
  #   - if :empty, we'll create one, but not populate or migrate it
  #   - otherwise (the default), we'll create one,
  #     restore from backup, and migrate it.
  #   We'll also set up the right database.yml (socket by default; port
  #   forces host/port instead; host is ignored without port)
  attr_accessor :database, :password, :adapter, :pool, :socket,
                :host, :port

  # (Not options...)
  attr_reader :apache_application

  def initialize(options={})
    options[:name] ||= self.class.name.underscore
    super(options)
    self.environment ||= :development
    self.repository_branch ||= :master
    self.document_root = "#{current_path}/public" unless shared_site?
    self.auth_realm ||= "protected area"
    self.adapter ||= 'mysql'
    if adapter == 'mysql'
      self.pool ||= 5
      # We'll use this socket, unless a port is specified,
      # in which case we'll use host and that port
      self.socket ||= '/var/run/mysqld/mysqld.sock'
      self.host ||= "127.0.0.1"
    end
  end

  def create_dependencies
    depends_on(:passenger) if url

    unless database == :none
      # TODO: Support alternative database servers
      if slave_database?
        depends_on :packages => { :name => "mysql-client" }
      elsif own_database?
        depends_on(:mysql_server)
      end
      depends_on :packages => { :name => "libmysqlclient-dev" }
      depends_on :ruby_gem => {
                   :name => "mysql",
                   :version => "2.8.1"
                 }
    end

  
    depends_on :directory => { :name => pids_path }
    depends_on :directory => { :name => system_path }
    depends_on :directory => { :name => releases_path }
    depends_on :directory => {
                 :name => log_path,
                 :dir_mode => 0777
               }
    depends_on :file => {
                 :name => "#{log_path}/#{environment}.log",
                 :touch => true,
                 :mode => 0666
               }

    if url
      depends_on(:directory => { :name => site_document_root }) \
        if shared_site?

      apache_options = SITE_OPTIONS.inject({}) {|h, k| h[k] = send(k); h}
      depends_on :apache_application => apache_options.merge(
                   :configuration => app_configuration
                 ),
                 :do_after => self
    end
  end

  def done?
    File.symlink?(current_path) && \
      ((database == :none) || File.exist?(shared_path + "/database.yml"))
  end

  def apply
    deploy_setup
    create_database
    install_gems
    try(:restore_database) if own_database?
    migrate_database
    fix_permissions
  end

  def own_database?
    # True if we own the database, and should create/migrate it, etc.
    case database
    when :none
      # log(:error, "(own_db? database is :none)")
      false
    when Hash
      # log(:error, "(own_db? hash, first key is #{database.keys.first.inspect})")
      database.keys.first != :slave
    else
      # log(:error, "(own_db? true)")
      true
    end
  end

  def slave_database?
    database.is_a?(Hash) && database[:slave]
  end

  def wrap_command(command)
    # Wrap a command so that the right environment & bundler & RVM setup is present for it
    bundle_prefix = "bundle exec " if File.exist?("#{current_path}/.bundle")
    "cd #{current_path} && /bin/bash -l -c 'RAILS_ENV=#{environment} #{bundle_prefix}#{command}'"
  end
  
  def current_path
    @current_path ||= "#{app_path}/current"
  end

  def shared_path
    @shared_path ||= "#{app_path}/shared"
  end

  def pids_path
    @pids_path ||= "#{shared_path}/pids"
  end

  def system_path
    @system_path ||= "#{shared_path}/system"
  end

  def cached_copy_path
    @cached_copy_path ||= "#{shared_path}/cached-copy"
  end

  def vendor_bundle_path
    @vendor_bundle_path ||= "#{shared_path}/vendor_bundle"
  end

  def rvmrc_path
    @rvmrc_path ||= "#{shared_path}/rvmrc"
  end

  def log_path
    @log_path ||= "#{shared_path}/log"
  end

  def releases_path
    @releases_path ||= "#{app_path}/releases"
  end

  def release_path
    @release_path ||= "#{releases_path}/#{release_timestamp}"
  end

  def release_timestamp
    @release_timestamp ||= Time.now.utc.strftime("%Y%m%d%H%M%S")
  end

  def app_configuration
    """
    RailsBaseURI #{uri.path}
    RailsEnv #{environment}
    
    # If our maintenance page exists, put that up instead.
    RewriteEngine On
    RewriteCond #{current_path}/system/maintenance.html -f
    RewriteCond %{REQUEST_URI} !\.(css|gif|ico|jpg|png)$
    RewriteCond %{SCRIPT_FILENAME} !maintenance.html
    RewriteRule ^.*$ #{current_path}/system/maintenance.html [L]
"""
  end

protected
  def deploy_setup
    # - We use the remote_cache strategy - set up the cache
    git_clone(repository_url, :to => 'cached-copy', :cwd => shared_path)
    git_checkout(:deploy, :from => repository_branch, :cwd => cached_copy_path)
    git_enable_submodules(cached_copy_path) if enable_submodules

    # - copy the cache to be the first release folder
    execute("rsync -lrpt --exclude=\".git\" #{cached_copy_path}/* #{release_path}")
    revision = git_revision(cached_copy_path, repository_branch)
    File.open("#{release_path}/REVISION", 'w') do |f|
      f.write(revision)
    end
    FileUtils.symlink(log_path, "#{release_path}/log")

    # - make this release folder "current"
    FileUtils.symlink(release_path, current_path)

    # - If this is a sub-URI-based app, symlink to our public folder
    #   for Passenger
    # (This only handles one-level sub-URIs for now)
    FileUtils.symlink("#{current_path}/public", "#{site_document_root}/#{uri.path}")\
      if shared_site?

    if using_bundler?
      # Write an .rvmrc file so that our app will use its own gemset,
      # and trust it.
#      File.open(rvmrc_path, 'w') {|f| f.puts "rvm --create default@#{name}"}
#      FileUtils.symlink(rvmrc_path, "#{current_path}/.rvmrc")
#      execute("rvm rvmrc trust #{current_path}")

      # We want to share gems between deployments
      FileUtils.mkdir_p(vendor_bundle_path)
      FileUtils.symlink(vendor_bundle_path, "#{current_path}/vendor/bundle")
    end

    # - make sure we have a tmp folders, with a pids symlink in it, and make sure it's writeable
    tmp_path = "#{current_path}/tmp"
    FileUtils.mkdir_p(tmp_path)
    FileUtils.symlink(pids_path, "#{tmp_path}/pids")
    FileUtils.symlink(system_path, "#{current_path}/public/system")
    FileUtils.chmod_R(0777, tmp_path)
  end

  def database_password
    @database_password ||= password || if own_database?
      RandomPassword.create
    else
      # Ask the master (repeatedly if necessary). This symlink is created
      # manually on the master using something like:
      #  depends_on :file => {
      #               :name => "/home/tunnel/some_name.database.yml",
      #               :symlink_to => "/var/www/domain/some_name/shared/database.yml"
      #               :owner => "tunnel", :group => "tunnel", :mode => 0600
      #             }
      master = database[:slave]
      database_yml = execute("sudo -u tunnel ssh tunnel@#{master} " +\
                             "cat /home/tunnel/#{name}.database.yml",
                             :retry_on_failure => true).output
      YAML.load(database_yml)[environment.to_s]["password"]
    end
  end

  def create_database
    # Create the database, and write out a database.yml for it
    if own_database?
      log(:progress, "Creating database #{name}")
      mysql = find_feature(:mysql_server)
      mysql.create_database(name)
      mysql.grant_access(name, database_password, name, :all)
    else
      log(:progress, "Not creating database #{name} " +
                     "(database is #{database.inspect})")
    end

    if database != :none
      database_yml_path = shared_path + "/database.yml"
      File.open(database_yml_path, 'w') do |f|
        adapter_options = case adapter
        when 'mysql'
          opts = ["  pool: #{pool}",
                  "  encoding: utf8"]
          if port
            opts << "  host: #{host}"
            opts << "  port: #{port}"
          else
            opts << "  socket: #{socket}"
          end
          opts.join("\n")
        else
          abort "Need to add support for '#{adapter}' databases!"
        end
        f.puts """#-----------------------------------------------
# Database configuration created by genii - DO NOT EDIT IN PLACE
#-----------------------------------------------
#{environment}:
  adapter: #{adapter}
  database: #{name}
  username: #{name}
  password: \"#{database_password}\"
#{adapter_options}
"""
      end
      FileUtils.symlink(database_yml_path,
                        "#{release_path}/config/database.yml",
                        :force => true)
    end
  end

  def install_gems
    # - Install required gems (TODO: use RVM gemsets)
    if using_bundler?
      log(:progress, "Using Bundler to install gems for #{name}")
      execute("bundle install --deployment", :context => self)
    else
      log(:progress, "Installing gems for #{name}")
      execute("gem install rails -v #{rails_version}",
              :context => self)
      execute("rake gems:install --trace",
              :context => self)
    end
  end

  def migrate_database
    return if (!own_database? || database == :none)
    log(:progress, "Migrating database #{name}")
    execute("rake db:migrate --trace", :context => self)
  end

  def using_bundler?
    File.exist?("#{current_path}/Gemfile")
  end

  def fix_permissions
    execute("chown -R www-data:www-data #{app_path}")
  end
end
