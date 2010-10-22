class FU
  # Logging versions of standard-lib method calls (plus a couple with more
  # leverage, fix! and write!)
  def self.chmod_dir(dir_mode, path)
    log(:debug, "chmod 0#{"%o" % dir_mode} #{path}")
    FileUtils.chmod(dir_mode, path)
  end

  def self.chmod_file(mode, path)
    new_mode = mode | (File.stat(path).executable? ? 0111 : 0)
    log(:debug, "chmod (file) 0#{"%o" % new_mode} #{path}")
    FileUtils.chmod(new_mode, path)
  end

  def self.chown(owner, group, name)
    log(:debug, "chown #{owner}:#{group} #{name}")
    FileUtils.chown(owner, group, name)
  end

  def self.chown_R(owner, group, name)
    log(:debug, "chown_R #{owner}:#{group} #{name}")
    FileUtils.chown_R(owner, group, name)
  end

  def self.copy(source, name)
    log(:debug, "copy #{source} #{name}")
    FileUtils.copy(source, name)
  end

  def self.cp_r(source, name)
    log(:debug, "cp_r #{source} #{name}")
    FileUtils.cp_r(source, name)
  end

  def self.fix!(name, options={})
    # Apply a bunch of attribute changes at once
    log(:debug, "Fixing #{name} to #{options.inspect}")
    dir_mode = options[:dir_mode]
    file_mode = options[:file_mode]
    owner = options[:owner]
    group = options[:group]
    Find.find(name) do |path|
      if File.stat(path).directory?
        FU.chmod_dir(dir_mode, path) if dir_mode
      elsif file_mode
        FU.chmod_file(file_mode, path)
      end
    end
    FU.chown_R(owner, group, name) if (owner || group)
  end

  def self.mkdir_p(name)
    log(:debug, "mkdir_p #{name}")
    FileUtils.mkdir_p(name)
  end

  def self.rm_f(name)
    log(:debug, "rm_f #{name}")
    FileUtils.rm_f(name)
  end

  def self.symlink(symlink_to, name, options={})
    log(:debug, "symlink #{symlink_to} #{name}#{", #{options.inspect}" unless options.empty?}")
    ::File.symlink(symlink_to, name, options)
  end

  def self.touch(name)
    log(:debug, "touching #{name}")
    FileUtils.touch(name)
  end

  def self.write!(name, content, options={})
    # Write file content and set attributes
    # Safe for writing secrets: mode/ownership is set before writing content.
    log(:debug, "write! #{name}")
    FileUtils.mkdir_p(File.dirname(name))
    ::File.open(name, 'w') do |f|
      FU.chmod(options[:mode], name) \
        if options[:mode]
      FU.chown(options[:owner], options[:group], name) \
        if (options[:owner] || options[:group])
      f.write(content)
    end
  end

  def self.unlink(name)
    log(:debug, "rm_rf #{name}")
    FileUtils.rm_rf(name)
  end
end