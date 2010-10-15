class Features::RubyGem < Feature
  attr_accessor :name, :version, :gemset

  def create_dependencies
    # Suppress generation of rubydocs; make sure we get github gems too for now
    depends_on :file => {
                 :name => "/etc/gemrc",
                 :content => """# -----------------------------------------
# Written by genii - DO NOT EDIT IN PLACE
# -----------------------------------------
install: --no-rdoc --no-ri
update: --no-rdoc --no-ri
:sources:
- http://rubygems.org/
- http://gems.github.com/
""",
               }

    # Do RVM first, unless we already have (avoids circular reference
    # from RVM's installation of required gems)
    depends_on(:rvm) unless find_feature(:rvm, :anything)
  end

  def done?
    return false unless find_feature(:rvm, :anything).done?
    return false unless execute("gem query -n #{name}",
                                :context => self).detect do |line|
      line =~ /^#{Regexp.escape name.to_s} \((.*)\)$/
    end  
    version.nil? || (version == :pre) || $1.split(', ').include?(version)
  end

  def apply
    unless done?
      version_option = case version
      when :pre
        " --pre"
      when nil
        ""
      else
        " -v #{version}"
      end
      execute("gem install #{name}#{version_option}", :context => self)
    end
  end

  def wrap_command(command)
    # Wrap a command with bash so that RVM setup is present for it; select a
    # gemset if necessary
    gemset_prefix = "rvm use @#{gemset} && " if gemset
    "/bin/bash -l -c '#{gemset_prefix}#{command}'"
  end
end
