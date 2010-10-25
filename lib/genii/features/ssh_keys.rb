class Features::SshKeys < Features::Directory
  # Copy SSH keys to this user's home directory and set up their permissions
  attr_accessor :login, :remote_hosts

  FORBIDDEN_OPTIONS = [:owner, :group, :dir_mode, :mode]
  def initialize(options={})
    bad_opts = options.keys & FORBIDDEN_OPTIONS
    abort("can't specify #{bad_opts} for SshKeys") unless bad_opts.empty?
    abort(":source is required for SshKeys") unless options[:source]
    options[:owner] = options[:group] = options[:login] || \
      abort(":login is required for SshKeys")
    options[:name] ||= (File.expand_path("~#{options[:login]}/.ssh") \
                        rescue "/home/#{options[:login]}/.ssh")
    options[:dir_mode] = 0700
    options[:mode] = 0600
    super(options)
  end

  def describe_options
    options.dup.delete_if {|k,v| FORBIDDEN_OPTIONS.include? k }
  end

  def apply
    super
    FU.write!("#{name}/COPIED_BY_GENII", genii_header("#{login}'s .ssh"))

    # make the public files readable by others
    ssh_files = Dir.glob(File.join(name, "*"))
    public_files = ssh_files.select {|f| f =~ /(authorized_keys|BY_GENII|.pub)$/ }
    FU.chmod_file(0644, public_files)

    # Cache host keys from any host (or user@hosts) names we were given
    [remote_hosts].flatten.compact.each do |host|
      host = host.to_s
      host = "#{login}@#{host}" unless host.index("@")
      retry_on_failure = host.index("@github.com") == nil
      execute("sudo -u #{login} ssh -o 'StrictHostKeyChecking=no' " +\
                      "-o 'PasswordAuthentication=no' #{host} echo",
              :ignore_error => true,
              :retry_on_failure => retry_on_failure)
    end
  end
end
