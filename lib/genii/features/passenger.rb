class Features::Passenger < Feature
  DEFAULT_GEM_VERSION = "3.0.4"

  attr_accessor :gem_version, :max_pool_size

  def initialize(options={})
    super(options)
    self.gem_version ||= DEFAULT_GEM_VERSION

    self.max_pool_size ||= default_max_pool_size
  end

  def create_dependencies
    depends_on :packages => {
                 :names => %w[apache2-prefork-dev libapr1-dev libaprutil1-dev
                              libcurl4-openssl-dev],
               }
    depends_on :ruby_gem => {
                 :name => :passenger,
                 :version => gem_version
               }
    depends_on :file => {
                 :name => '/etc/apache2/mods-enabled/passenger.conf',
                 :owner => :root, :group => :root, :mode => 0644,
                 :source => "passenger/passenger.conf.erb",
                 :erb => { :passenger_version => gem_version,
                           :passenger_ruby_version => default_ruby_version,
                           :max_pool_size => max_pool_size,
                          }
               },
               :do_after => self
  end

  def done?
    File.exist? "#{gem_path}/ext/apache2/mod_passenger.so"
  end

  def apply
    execute("rvm #{default_ruby_version} --passenger", :context => rvm)

    execute("/usr/local/rvm/gems/#{default_ruby_version}" +
            "/gems/passenger-#{gem_version}/bin" +
            "/passenger-install-apache2-module --auto",
            :context => rvm)
  end

  def gem_path
    "/usr/local/rvm/gems/#{default_ruby_version}" +
      "/gems/passenger-#{gem_version}"
  end

  def default_ruby_version
    @default_ruby ||= rvm.default_ruby_version
  end

  def default_max_pool_size
    @default_max_pool_size ||= begin
      # How many instances should Passenger run, max?
      # ((total_mem in MB) - (mem for Mysql) - (mem for Redis)) / (60MB/instance)
      # eg (768 - 100 - 50) / 60 = 5
      mysql_present = !find_feature(:mysql_server, :anything).nil?
      redis_present = !find_feature(:redis, :anything).nil?
      memory = /(\d+)/.match(execute("grep MemTotal /proc/meminfo").output)[1].to_i / 1024
      memory -= 100 if mysql_present
      memory -= 50 if redis_present
      instances = memory / 60 # assume each Rails instance costs 100MB
      instances = 2 if instances < 2
      log(:info, "Using calculated max_pool_size = #{instances} (redis=#{redis_present.inspect}, mysql=#{mysql_present.inspect}")
      instances
    end
  end

  def rvm
    @rvm ||= find_feature(:rvm, :anything)
  end
end
