
class Features::TimeAndZone < Feature
  attr_accessor :timezone

  def initialize(options={})
    super(options)
    self.timezone ||= 'America/Los_Angeles'
  end

  def create_dependencies
    depends_on :packages => { :name => :ntp }
  end

  def apply
    execute([
      "echo '#{timezone}' > /etc/timezone",
      "dpkg-reconfigure --frontend noninteractive tzdata",
      "/etc/init.d/cron restart"
    ].join('; '))
  end
  
  def done?
    execute("date").output !~ /UTC/
  end
end
