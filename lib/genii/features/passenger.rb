class Features::Passenger < Feature
  DEFAULT_GEM_VERSION = "3.0.3"

  attr_accessor :gem_version

  def initialize(options={})
    super(options)
    self.gem_version ||= DEFAULT_GEM_VERSION
  end

  def create_dependencies
    depends_on :packages => {
                 :names => %w[apache2-prefork-dev libapr1-dev libaprutil1-dev],
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
                           :passenger_ruby_version => default_ruby_version }
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

  def rvm
    @rvm ||= find_feature(:rvm, :anything)
  end
end
