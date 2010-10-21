require 'munge'
require 'etc'

class Features::Rvm < Feature
  # The rvm and ruby we'll default to, if no defaults are configured
  # DEFAULT_RVM_REVISION = :HEAD # just use head for now
  DEFAULT_RVM_REVISION = "1.0.15"
  DEFAULT_RUBY_VERSION = "ree-1.8.7-2010.02"

  # without :revision, you get the DEFAULT_RVM_REVISION above
  # :revision => :HEAD overrides the default RVM revision above to get latest
  attr_accessor :rubies, :revision

  def initialize(options={})
    super(options)
    self.revision ||= DEFAULT_RVM_REVISION 
    self.rubies ||= [DEFAULT_RUBY_VERSION]
  end

  def create_dependencies
    depends_on :packages => {
                 :names => %w[build-essential curl libreadline5-dev
                              libssl-dev zlib1g-dev]
               }

# Not needed? (now that they're part of global.gems below)
#    # Always install ruby-debug, just to prevent deployment issues if I
#    # accidentally leave a require in place
#    depends_on :ruby_gem => {
#                 :name => "ruby-debug",
#                 :gemset => :global
#               },
#               :do_after => self
#
#    # Install Bundler to aid in deployment
#    depends_on :ruby_gem => {
#                 :name => :bundler,
#                 :gemset => :global
#               },
#               :do_after => self
  end

  def apply
    apply_bashrc_fixes unless bashrc_fixes_done?
    apply_rvm unless rvm_done?
    apply_ree unless ree_done?
  end

  def done?
    bashrc_fixes_done? && rvm_done? && ree_done?
  end

  def default_ruby_version
    self.rubies.first
  end

  def wrap_command(command)
    # Wrap a command with bash so that RVM setup is present for it
    "/bin/bash -l -c '#{command}'"
  end

private

  def apply_bashrc_fixes
    all_bashrc_files.each {|p| fix_bashrc(p) }
  end

  def bashrc_fixes_done?
    all_bashrc_files.all? {|p| fixed_bashrc?(p)}
  end

  def all_bashrc_files
    results = ['/etc/bash.bashrc',
              '/etc/skel/.bashrc']
    begin
      while (entry = Etc.getpwent) do
        bash_path = File.join(entry.dir, ".bashrc")
        results << bash_path if File.exist?(bash_path)
      end
    ensure
      Etc.endpwent
    end
    results
  end

  def fixed_bashrc?(path)
    IO.read(path).index("RVMstart")
  end

  def fix_bashrc(path)
    input = IO.read(path)
    return if input.index("RVMstart")
    log(:progress, "Fixing #{path} for RVM")
    
    output = Munger.munge(:input => input, :mode => :replace,
      :pattern => /^\[ -z \"\$PS1\" \] \&\& return$/,
      :content => "# BJS: replaced '&& return' with open conditional, for RVM\n" +
                  "if [ ! -z \"$PS1\" ]; then",
      :tag => "# RVMstart ")
    output = Munger.munge(:input => output, :mode => :append,
      :content => """
# BJS: added to close the open conditional above
fi

# Load system-wide RVM
[[ -s '/usr/local/rvm/scripts/rvm' ]] && source '/usr/local/rvm/scripts/rvm' && source '/usr/local/rvm/scripts/completion'
""",
      :tag => "# RVMend ")
    File.open(path, 'w') {|f| f.write(output) }
  end

  def apply_rvm
    log(:progress, "Installing RVM #{revision if revision}")
    force_revision = "--revision #{revision} " \
      if (revision && revision != :HEAD)

    # Grab and run an RVM system-wide install script
    installer_revision = (revision && revision != :HEAD) ? revision : "master"
    # Use Wayne's
    log(:noisy, execute("curl -L http://github.com/wayneeseguin/rvm/raw/#{installer_revision}/contrib/install-system-wide > /tmp/rvm-install && " +
                        "bash /tmp/rvm-install").output)
    # Use a local one when hacking
    # log(:noisy, execute("bash #{File.dirname(__FILE__)}/rvm/install-system-wide #{force_revision}").output)

    File.open("/usr/local/rvm/gemsets/global.gems", 'w') do |f|
      f.write """
bundler
mysql -v2.8.1
rake
ruby-debug
"""
    end

    # Create gemsets automatically on first use
    Munger.munge(:path => "/etc/rvmrc", :mode => :before, :pattern => /^fi/,
                 :content => "  export rvm_gemset_create_on_use_flag=1",
                 :tag => "  # ")
  end

  def apply_ree
    log(:progress, "Installing REE")
    log(:noisy, execute("rvm install #{default_ruby_version} && " + \
            "rvm use #{default_ruby_version} --default").output)
    log(:noisy, execute("rvm info").output)
  end

  def rvm_done?
    File.exist?("/usr/local/lib/rvm")
  end

  def ree_done?
    File.directory?("/usr/local/rvm/rubies/#{default_ruby_version}")
  end
end
