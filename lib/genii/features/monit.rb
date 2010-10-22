class Features::Monit < Feature
  # One monitored thing; you'll want one for the system that's
  # depends_on :monit => { :content => Monit.common(...) }
  #
  # A few other common monitoring configurations are below too, like
  # :ping.
  #
  # Most of our monitoring rules end with mode manual; we wait
  # 60 seconds before turning on the monitors using monit_delay

  attr_accessor :name, :content

  def create_dependencies
    # Don't run monit on 'testing' machines at all
    return if machine.configuration[:testing] == true

    depends_on :packages => { :name => 'monit' }

    depends_on :file => {
                 :name => "/etc/default/monit",
                 :replace => {
                   :pattern => /^startup=0$/,
                   :content => "startup=1",
                   :tag => "# "
                 }
               }
    depends_on :file => {
                 :name => '/etc/monit/monitrc',
                 :append => {
                   :content => "include /etc/monit/conf.d/*",
                   :tag => "# "
                 }
               }

    depends_on :file => {
                 :name => '/etc/monit/monit_delay',
                 :content => "sleep 60; /usr/sbin/monit monitor all\n",
                 :mode => 0755
               }
    depends_on :file => {
                 :name => '/usr/local/bin/monit_top',
                 :source => "monit/monit_top",
                 :mode => 0755
               }

    depends_on :file => {
                 :name => "/etc/monit/conf.d/#{name}",
                 :content => genii_header("Monit: #{name}") + content,
                 :mode => 0600,
               }

    depends_on :directory => {
                 :name => "/var/spool/monit",
                 :mode => 0644,
               }

    depends_on :service => { :name => :monit },
               :do_after => machine

    nothing_else_to_do! unless name
  end

  def describe_options
    # Shorten any file contents we were given
    result = options.dup
    result[:content] &&= result[:content].elided
    result
  end

  def self.common(options={})
    options[:interval] = 180 # checking every three minutes is enough
    options[:notify] ||= "root@#{`hostname --fqdn`.strip}"
    options[:notify_return] ||= options[:notify]
    options[:mail_server] ||= "localhost"
    options[:disk_threshold] ||= 70

    content = ["""  set logfile syslog

  set daemon #{options[:interval]}
  set eventqueue basedir /var/spool/monit

  set mailserver #{options[:mail_server]}
  set alert #{options[:notify]}
    not { action, instance }
    with mail-format { from: #{options[:notify_return]} }
    with reminder on 50 cycles

  # Run the webserver on the local interface only, without authentication
  # (only SSH'd port forwarding can access it)
  set httpd port 2812
    use address localhost
    allow localhost

  check system server
    if loadavg (1min) > 4 for 2 cycles then alert
    if loadavg (5min) > 2 for 2 cycles then alert
    if memory usage > 75% then alert
    if cpu usage (system) > 30% for 2 cycles then alert
    if cpu usage (wait) > 30% for 2 cycles
      then exec \"/usr/local/bin/monit_top\"
      else if recovered
        then exec \"/bin/bash -c 'kill `cat /tmp/monit_top.pid` && cat /tmp/monit_top.out | mail -s 'Monit High CPU Usage Wait Alert' #{options[:notify]}\"
    if cpu usage (user) > 70% for 2 cycles
      then exec \"/usr/local/bin/monit_top\"
      else if recovered
        then exec \"/bin/bash -c 'kill `cat /tmp/monit_top.pid` && cat /tmp/monit_top.out | mail -s 'Monit High CPU Usage User Alert' #{options[:notify]}\"

"""]

    # Add a check for each real filesystem
    `df -x tmpfs -x devtmpfs -x debugfs | tail -n +2 | cut -f 1 -d ' '`\
      .each_line do |device|
      device.chomp!
      device_name = device[device.rindex('/') + 1 .. -1]
      content << "check device dev_#{device_name} with path #{device}\n" +\
                 "  if space > #{options[:disk_threshold]} percent then alert\n"
    end

    { :name => "_common",
      :content => content.join("\n") }
  end

  def self.ping(hostname)
    content = """  check host #{hostname} with address #{hostname}
    if failed icmp type echo count 10 with timeout 10 seconds
      for 3 times within 5 cycles then alert
    mode manual
"""
    { :name => "check_#{hostname.to_s.gsub(/\./,'_')}",
      :content => content }
  end
end
