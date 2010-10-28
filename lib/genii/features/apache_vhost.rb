class Features::ApacheVhost < Feature
  include SiteInfo

  # A top-level Apache vhost
  # - we'll overwrite /etc/apache2/httpd.conf if httpd_conf is set
  #
  # - If the SSL options are given, we'll use HTTPS (and port 443 unless
  #   port is given); if port is 443 and non_ssl_redirect isn't false,
  #   we'll add another vhost to redirect from port 80.
  #
  # - We'll protect the entire vhost if auth_users is given
  #
  # - If configuration is provided, we'll put it in the <VHost..> block
  #

  # We disable these modules
  DISABLE_MODULES = %w[auth_basic.load autoindex.load autoindex.conf
                       status.load status.conf]
  # We enable these modules
  ENABLE_MODULES = %w[auth_digest.load proxy.load proxy.conf proxy_http.load
                      rewrite.load ssl.load ssl.conf]

  # site_info's, plus:
  attr_accessor :ip, :aliases, :configuration, :httpd_conf

  def initialize(options={})
    super(options)
    abort "Can't do SSL without certificates (#{options.inspect})" \
      if (ssl? && ssl_certificate_file.nil?)
    self.name ||= site_name
    self.auth_realm ||= "protected area"
  end

  def create_dependencies
    depends_on :packages => { :name => :apache2 }

    if httpd_conf
      depends_on :file => {
                   :name => '/etc/apache2/httpd.conf',
                   :source => httpd_conf,
                 }
    end

    depends_on :directory => {
                 :name => site_files_path,
                 :dir_mode => 0775
               }

    depends_on(:file => {
                 :name => "/etc/apache2/conf.d/nvh_#{ip.gsub('.','_')}",
                 :content => """#{genii_header("port configuration for #{ip}")}
#{"Listen #{uri.port}" unless [80,443].include? uri.port}
NameVirtualHost #{ip}:#{uri.port}
"""
               })\
      if ip

    if ssl_certificate_file
      [ssl_certificate_file, ssl_certificate_key_file,
       ssl_certificate_chain_file].compact.each do |file|
        depends_on :file => {
                     :name => "#{site_files_path}/#{File.basename(file)}",
                     :source => file,
                     :mode => 0444
                   }
      end
    end

    depends_on :directory => {
                 :name => site_document_root,
                 :mode => 0664
               }

    # Give our monitoring something to check for
    depends_on :file => {
                 :name => "#{site_document_root}/uptime.txt",
                 :content => "success",
                 :mode => 0664
               }

    depends_on :firewall => { :tcp => uri.port }
    depends_on(:firewall => { :tcp => 80 }) \
      if ssl? and non_ssl_redirect != false

    # Disable some modules
    DISABLE_MODULES.each do |mod|
      depends_on :file => {
                   :name => "/etc/apache2/mods-enabled/#{mod}",
                   :unlink => true
                 }
    end

    # Enable more modules
    ENABLE_MODULES.each do |mod|
      depends_on :file => {
                   :name => "/etc/apache2/mods-enabled/#{mod}",
                   :symlink_to => "/etc/apache2/mods-available/#{mod}"
                 }
    end

    # Enable reverse proxying
    depends_on :file => {
                 :name => '/etc/apache2/mods-enabled/proxy.conf',
                 :replace => {
                   :tag => "                # allow reverse proxying",
                   :pattern => /^\s+Deny from all$/,
                   :content => "                # Deny from all"
                 }
               }

    # Write out an authfile if we're using authentication
    depends_on(:file => {
                 :name => auth_path,
                 :content => auth_passwords
               })\
      if auth_users

    depends_on :directory => {
                 :name => "/etc/apache2/apps-enabled"
               }

    depends_on :file => {
                 :name => site_config_path,
                 :content => site_configuration
               }

    depends_on(:file => {
                 :name => "/etc/apache2/sites-enabled/default-ssl",
                 :unlink => true
               })\
      if localhost80?

    depends_on :monit => {
                 :name => "apache",
                 :content => monit_content
               },
               :do_after => self

    depends_on :service => { :name => :apache2 },
               :do_after => self

    depends_on :site_permissions,
               :do_after => machine
  end

  def describe_options
    # Shorten any configuration we were given
    result = options.dup
    [:configuration, :httpd_conf].each do |sym|
      if result[sym].is_a? String
        result[sym] = result[sym].elided
      end
    end
    result
  end

  def site_configuration
    """#{genii_header("site configuration for #{ip || "*"}:#{uri.port}")}
#{listen_setting}
<VirtualHost #{ip || "*"}:#{uri.port}>
  #{host_setting}#{alias_setting}
  ErrorLog /var/log/apache2/#{name}.error.log
  CustomLog /var/log/apache2/#{name}.access.log combined
  RewriteEngine On
  #RewriteLog /var/log/apache2/#{name}.rewrite.log
  #RewriteLogLevel 9
  DocumentRoot #{site_document_root}
  #{ssl_configuration}
  #{auth_configuration}
  Include /etc/apache2/apps-enabled/*__#{site_name}
</VirtualHost>
#{non_ssl_redirect_configuration}
"""
  end

  def listen_setting
    "Listen #{uri.port}" unless [80,443].include? uri.port
  end

  def ssl_configuration
    # Configuration of an SSL site
    @ssl_configuration ||= if ssl?
      files = [[:SSLCertificateFile, ssl_certificate_file]]
      files << [:SSLCertificateKeyFile, ssl_certificate_key_file] \
        if ssl_certificate_key_file
      files << [:SSLCertificateChainFile, ssl_certificate_chain_file] \
        if ssl_certificate_chain_file
    """
  SSLEngine on
  SSLVerifyClient none
#{files.map{|k,v| "  #{k} #{site_files_path}/#{File.basename(v)}\n"}}  <Location />
    SSLRequireSSL
  </Location>
"""
    end
  end

  def non_ssl_redirect_configuration
    # Configuration for a non-SSL site that redirects to its SSL version
    return "" unless ssl? and non_ssl_redirect != false

    # We'll redirect to the SSL version of the same URL unless one was specified
    # (which can also end with %{REQUEST_URI} to preserve the path)
    to_uri = non_ssl_redirect || "https://#{uri.host}%{REQUEST_URI}"
    """
<VirtualHost #{ip || "*"}:80>
  ServerName #{uri.host}#{alias_setting}
  RewriteEngine On
  #RewriteLog /var/log/apache2/#{site_name}_to-ssl.rewrite.log
  #RewriteLogLevel 9
  RewriteCond %{SERVER_PORT} !^443$
  RewriteRule ^(/uptime.txt)$ $1 [L]
  RewriteRule ^.*$ #{to_uri} [L,R]
</VirtualHost>
"""
  end

  def host_setting
    "ServerName #{uri.host}" unless localhost80?
  end

  def alias_setting
    alias_names = aliases
    alias_names ||= "www.#{uri.host}" if uri.host.index(".")
    "\n  ServerAlias #{alias_names}" if alias_names
  end

  def monit_content
    """check process apache with pidfile /var/run/apache2.pid
  start program = \"/etc/init.d/apache2 start\"
  stop program = \"/etc/init.d/apache2 stop\"
  if failed port 80 protocol http then restart
  if 3 restarts within 5 cycles then timeout
  mode manual
"""
  end
end
