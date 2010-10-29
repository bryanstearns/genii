class Features::ApacheApplication < Feature
  include SiteInfo
  # An application's configuration in Apache (see site_info for
  # more details)
  #
  # - The base URL should include http:// or https://,
  #   the domain name, and any leading path
  # - document_root is the location where the web content is based
  #   (for a Rails app, it's the path to /public)
  # - if auth_users is defined, it's a hash of users and passwords
  #   for digest authentication in this realm
  # - If it's ssl, ssl_certificate_file is required (along with an optional
  #   chain file or key file); non-SSL requests will be redirect to the SSL
  #   version unless you set non_ssl_redirect to false (or to another URL)
  # - configuration is an optional hash of extra parameters to include
  #   in the app's configuration; local_configuration is also included,
  #   within a Location or Directory block.
  # - or, instead of the configurations, proxy (actually, reverse_proxy) to
  #   a port with :proxy_to => 8080, or a full url with
  #   :proxy_to => "http://something/"
  #
  # If all you want is default redirection for non-vhost requests,
  # just pass :redirect_to => url.
  attr_accessor *SITE_OPTIONS
  attr_accessor :redirect_to, :proxy_to, :configuration, :local_configuration

  def initialize(options={})
    options[:url] ||= "http://localhost"
    super(options)
    self.auth_realm ||= "protected area"
  end

  def create_dependencies
    depends_on :service_restart => { :name => :apache2 }, 
               :do_after => self

    depends_on :site_permissions,
               :do_after => machine
  end

  def describe_options
    # Shorten any configuration we were given
    result = options.dup
    result[:local_configuration] = result[:local_configuration].elided \
      if result[:local_configuration].is_a? String
    result[:configuration] = result[:configuration].elided \
      if result[:configuration].is_a? String
    result
  end

  def done?
    auth_done? && app_config_done?
  end

  def apply
    log(:progress, "configuring apache")
    FU.write!(auth_path, auth_passwords) unless auth_done?
    FU.write!(app_config_path, app_configuration)
  end

private

  def app_config_done?
    File.exist?(app_config_path)
  end

  def simple_redirection_configuration
    """  # Redirect everything
  RewriteEngine On
  RewriteRule ^.*$ #{redirect_to} [L,R]
"""
  end

  def proxy_configuration
    proxy_url = proxy_to
    proxy_url = "http://127.0.0.1:#{proxy_to}" if proxy_to.is_a?(Numeric)
    path_wildcard = uri.path == "/" ? "*" : "#{uri.path}/*"
    log(:error, "proxyconfig after: url=#{proxy_url.inspect}, to=#{proxy_to.inspect}, uri=#{uri.inspect}")
    """
    # We're a reverse proxy
    ProxyRequests Off
    ProxyVia Block
    <Proxy #{path_wildcard}>
        Order deny,allow
        Allow from all
    </Proxy>
    ProxyPass #{uri.path} #{proxy_url}
    ProxyPassReverse #{uri.path} #{proxy_url}
"""
  end

  def app_configuration
    # The details of app configuration, which'll be embedded into the
    # virtual host if this is the only app on the domain, or stuck in
    # a Directory tag in its own file if shared.
    @app_configuration ||= begin
      lines = ["# App configuration for #{name} at #{url}"]

      lines << "  Alias #{uri.path} \"#{document_root}\"" \
        if document_root && shared_site? && uri.path != '/'

      if proxy_to
        lines << proxy_configuration
      else
        lines << configuration if configuration

        configuration_content = redirect_to \
          ? simple_redirection_configuration \
          : local_configuration
        if document_root || (configuration_content && \
                             configuration_content.strip.length > 0)
          lines << if (shared_site? || document_root.nil?)
            "  <Location #{uri.path}>\n" +
            "    #{configuration_content}\n" +
            "  </Location>"
          else
            "  DocumentRoot #{document_root}\n" +
            "  <Directory #{document_root}>\n" +
            "    #{configuration_content}\n" +
            "  </Directory>"
          end
        end
      end

      lines << "  #{auth_configuration}" if auth_configuration
      lines.join("\n")
    end
  end
end

