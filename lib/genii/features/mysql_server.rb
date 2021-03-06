class Features::MysqlServer < Feature
  include UsersAndGroups

  attr_accessor :root_password

  def initialize(options={})
    super(options)
    self.root_password ||= (load_password('root') || RandomPassword.create)
  end

  def create_dependencies
    depends_on :packages => {
                 :names => %w[mysql-server mysql-client mytop]
               }
    depends_on :file => {
                 :name => "/etc/mysql/conf.d/encodings.cnf",
                 :content => """#{genii_header("Force utf8")}
[client]
default-character-set=utf8
  
[mysqld]
default-character-set=utf8
character-set-server=utf8
default-collation=utf8_unicode_ci
"""
               }

    depends_on :file => {
                 :name => "/etc/mysql/conf.d/pidfile.cnf",
                 :content => """#{genii_header("Write MySQL's pidfile for Monit")}
[mysqld]
pid-file = /var/run/mysqld/mysqld.pid
"""
               }

    depends_on :monit => {
                 :name => "mysql",
                 :content => monit_content
               },
               :do_after => self

    depends_on :service => { :name => :mysql },
               :do_after => self
  end

  def apply
    # Set the root database password
    password = root_password
    execute("mysql -u root -D mysql " +
            "-e \"update user set password=PASSWORD('#{password}') " +
            "where user = 'root'; flush privileges;\"")

    # Write out the password for all users in the sudo group
    log(:progress, "Writing .my.cnf files for sudo users")
    sudo_users = get_group_entry(:sudo).mem + ['root']
    sudo_users.each {|login| write_password(login, 'root', password) }
  end

  def done?
    File.exist?(my_cnf_path(get_group_entry(:sudo).mem.first))
  end

  def execute_sql(sql, options={})
    arguments = ["-uroot -p#{root_password} -D#{options[:database] || :mysql}"]
    if options[:batch]
      arguments << "--batch"
    elsif log_detail?
      arguments << "-v -v -v"
    end
    execute("echo \"#{sql}\" | mysql #{arguments.join(' ')}")
  end

  def create_database(name)
    execute_sql("create database #{name} default character set utf8")
  end

  def grant_access(user_name, password, database_name, privileges)
    privileges = case privileges
    when :all
      "ALL PRIVILEGES"
    when :replication
      "REPLICATION SLAVE, REPLICATION CLIENT, RELOAD, SELECT"
    else
      privileges
    end
    execute_sql("GRANT #{privileges} ON #{database_name}.* " +\
                "TO '#{user_name}'@localhost " +\
                "IDENTIFIED BY '#{password}'; FLUSH PRIVILEGES;")
  end


  def my_cnf_path(login)
    File.expand_path("~#{login}/.my.cnf")
  end

  def write_password(login, user, password)
    password_content = """[client]
user=#{user}
password=#{password}
"""
    FU.write!(my_cnf_path(login), password_content,
              :mode => 0600, :owner => login, :group => login)
  end

  def load_password(login)
    # Load the existing password for this user. Return nil if there isn't one, but
    # die if there's a config file we can't parse.
    cnf_path = my_cnf_path(login)
    return nil unless File.exist?(cnf_path)
    content = IO.read(cnf_path)
    parse_password(login, content)
  end

  def parse_password(login, content)
    abort("Can't find password in #{login}'s .my.cnf: '#{content}'") \
      unless /^password\=(.*)$/.match(content)
    $1
  end

  def monit_content
    """check process mysql with pidfile /var/run/mysqld/mysqld.pid
  start program = \"/etc/init.d/mysql start\"
  stop program = \"/etc/init.d/mysql stop\"
  if 3 restarts within 5 cycles then timeout
  if failed port 3306 then restart
  mode manual
"""
  end
end

