require 'digest/md5'

module SiteInfo
  # Our standards for Apache site & application paths, configuration, etc.
  #
  # We configure "sites" (for top-level vhost domains) and "apps";
  #
  # In /etc/apache2, we use the predefined /sites-enabled dir to store
  # configuration for each virtual host; there's a configuration
  # file that's its domain name with dots changed to underscores.
  # If the port is nonstandard, it's appended after another '_'; if
  # the definition is SSL-only, we add '_ssl' (unless the definition
  # also includes redirection from port 80, which is the default).
  # 
  # We use /apps-enabled for applications within each vhost: each
  # has a configuration file with the name of the app, two '_'s, then
  # the site name; this allows us to unambiguously include all of a
  # site's applications from its site configuration.
  #
  # We store any site-related configuration files in /site-files --
  # certificates and digest-auth files, mostly.
  #
  # Each app's content goes in '/var/www/(app name)';
  # each site may also have a '/var/www/htdocs_(site_name)' directory
  # (where we put Passenger redirect symlinks for Rails apps based
  # at sub-URIs).
  #
  # This module parses the URL returned by :url and provides
  # memoized values for all the related paths. The :url value
  # should include http:// or https://, the domain name, and any 
  # leading path
  #
  # These are all options for features that include SiteInfo
  # (like ApacheApplication or RailsAppInstance):
  # 
  # :name: the name of the app (unique on machine)
  #
  # - If the base URL isn't specified, don't setup the web stuff:
  #   we're a backend instance only. Otherwise, we pass these to
  #   set up our apache_application
  SITE_OPTIONS = [:url, :name, :document_root,
                  :auth_users, :auth_realm, :auth_type,
                  :ssl_certificate_file, :ssl_certificate_key_file,
                  :ssl_certificate_chain_file, :non_ssl_redirect,
                  :force_shared]
  attr_accessor *SITE_OPTIONS

  def uri
    @uri ||= (url || "http://localhost").to_uri
  end

  def shared_site?
    # Does this site share this domain?
    # (or is it rooted at '/' and own the whole thing)
    (uri.path != '/') || force_shared
  end

  def ssl?
    uri.scheme == "https"
  end

  def localhost80?
    uri.host == "localhost" && uri.port == 80
  end

  def site_name
    @site_name ||= begin
      result = uri.host.gsub('.', '_')
      result += "_#{uri.port}" if ![80, 443].include?(uri.port)
      result
    end
  end

  def app_name
    @app_name ||= "#{name}__#{site_name}"
  end

  def apps_path
    "/var/www"
  end

  def site_document_root
    @site_document_root ||= (shared_site? || document_root.nil?) \
      ? "#{apps_path}/htdocs_#{site_name}" \
      : document_root
  end

  def app_path
    @app_path ||= "#{apps_path}/#{name}"
  end

  def site_config_path
    @site_config_path ||= "/etc/apache2/sites-enabled/" +
      (localhost80? ? "000-default" : site_name)
  end

  def site_files_path
    @site_files_path ||= "/etc/apache2/site-files/#{site_name}"
  end

  def app_config_path
    @app_config_path ||= "/etc/apache2/apps-enabled/#{app_name}"
  end

  def auth_path
    @auth_path ||= "#{site_files_path}/#{name}.auth"
  end

  def auth_done?
    !auth_users || File.exist?(auth_path)
  end

  def auth_salt
    @letters ||= [*'a'..'z'] + [*'A'..'Z'] + [*'0'..'9'] + %w(/ .)
    @letters[rand @letters.length] + @letters[rand @letters.length]
  end

  def auth_passwords
    @auth_passwords ||= auth_users.map do |user, password|
      case (auth_type || :digest)
      when :digest
        hash = Digest::MD5.new.update("#{user}:#{auth_realm}:#{password}").hexdigest
        "#{user}:#{auth_realm}:#{hash}"
      when :basic
        "#{user}:#{password.crypt(auth_salt)}"
      end
    end.join("\n")
  end
  
  def auth_configuration
    @auth_configuration ||= if auth_users
      """
  <Location #{uri.path}>
    AuthType #{(auth_type || :digest).to_s.capitalize}
    AuthName \"#{auth_realm}\"
    AuthUserFile \"#{auth_path}\"
    require valid-user
  </Location>
"""
    end
  end
end
