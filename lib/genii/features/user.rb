class Features::User < Feature
  # An account for a user, plus their SSH keys
  include UsersAndGroups
  
  attr_accessor :login, :name, :password, :shell, :uid, :system, :home_dir

  def initialize(options=nil)
    super(options)
    raise ArgumentError, "User #{options.inspect} requires login" \
      unless login
    self.password ||= 'PASSWORD LOGIN DISABLED'
    self.name ||= login
  end

  def apply
    log(:details, "Creating user #{login}")
    execute(create_command)
  end

  def done?
    get_user_entry(login)
  end

  def create_command
    command = [ "useradd -m" ]
    command << (system ? "-r" : "-p '#{password}'")
    command << "-u #{uid}" if uid
    command << "-s #{shell}" if shell
    command << "-d #{home_dir}" if home_dir
    command << login
    command.join(' ')
  end
end
