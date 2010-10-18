class Features::SendMail < Feature
  # Set up outgoing mail (with Exim4, not sendmail, I lied.)
  # You probably ought to set a mail alias for root (which applies to all
  # the admin mail this server sends); all_mail_to is helpful when testing a
  # server -- all mail sent by the server (including root's, no matter what
  # root_alias is) goes to that address.
  attr_accessor :root_alias, :all_mail_to

  def create_dependencies
    depends_on :packages => {
                 :names => %w[exim4-daemon-light mailutils]
               }

    # Tell Exim that we do want mail delivery, and to use the split config
    # mechanism; see http://pkg-exim4.alioth.debian.org/README/README.Debian.etch.html#id222005
    depends_on :file => {
                 :name => "/etc/exim4/update-exim4.conf.conf",
                 :replace => {
                     :tag => "# configtype",
                     :pattern => /^dc_eximconfig_configtype\=/,
                     :content => "dc_eximconfig_configtype='internet'"
                 }
               }
    depends_on :file => {
                 :name => "/etc/exim4/update-exim4.conf.conf",
                 :replace => {
                     :tag => "# use_split_config",
                     :pattern => /^dc_use_split_config\=/,
                     :content => "dc_use_split_config='true'"
                 }
               }

    if root_alias
      depends_on :file => {
                   :name => "/etc/aliases",
                   :append => {
                       :tag => "# redirect admin mail",
                       :content => "root: #{root_alias}"
                   }
                 }
    end

    if all_mail_to
      depends_on :file => {
                   :name => "/etc/exim4/conf.d/router/01_exim4-config_redirect_all",
                   :content => """#{genii_header("Redirect all mail to one address")}
redirect_all:
  driver = redirect
  data = #{all_mail_to}
"""
                 }
    end

    depends_on :monit => {
                 :name => "exim4",
                 :content => monit_content
               },
               :do_after => self

    depends_on :service => { :name => :exim4 },
               :do_after => self
  end

  def done?
    false
  end

  def apply
    # rebuild the hierachy
    execute("update-exim4.conf")
  end

private
  def monit_content
    """check process exim4
  with pidfile /var/run/exim4/exim.pid
  start program = \"/etc/init.d/exim4 start\"
  stop program = \"/etc/init.d/exim4 stop\"
  if failed host 127.0.0.1 port 25 protocol smtp then restart
  if 3 restarts within 5 cycles then timeout
  mode manual

"""
  end
end