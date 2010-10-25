class FU
  # Logging versions of standard-lib method calls (plus a couple with more
  # leverage, fix! and write!)
  def self.chmod_dir(dir_mode, paths)
    log(:debug, "chmod 0#{"%o" % dir_mode} #{paths}")
    FileUtils.chmod(dir_mode, paths)
  end

  def self.chmod_file(mode, paths)
    [paths].flatten.each do |path|
      new_mode = mode.to_i | ((File.stat(path).executable? rescue false) ? 0111 : 0)
      log(:debug, "chmod (file) 0#{"%o" % new_mode} #{path}")
      FileUtils.chmod(new_mode, path)
    end
  end

  def self.chown(owner, group, names)
    log(:debug, "chown #{owner}:#{group} #{names}")
    FileUtils.chown(owner, group, names)
  end

  def self.chown_R(owner, group, names)
    log(:debug, "chown_R #{owner}:#{group} #{names}")
    FileUtils.chown_R(owner, group, names)
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

  def self.mkdir_p(names)
    log(:debug, "mkdir_p #{names}")
    FileUtils.mkdir_p(names)
  end

  def self.rm_f(*names)
    log(:debug, "rm_f #{names}")
    FileUtils.rm_f(names)
  end

  def self.symlink(symlink_to, name, options={})
    log(:debug, "symlink #{symlink_to} #{name}#{", #{options.inspect}" unless options.empty?}")
    FileUtils.symlink(symlink_to, name, options)
  end

  def self.touch(names)
    log(:debug, "touching #{names}")
    FileUtils.touch(names)
  end

  def self.write!(name, content, options={})
    # Write file content and set attributes
    # Safe for writing secrets: mode/ownership is set before writing content.
    log(:debug, "write! #{name}")
    FileUtils.mkdir_p(File.dirname(name))
    ::File.open(name, 'w') do |f|
      FU.chmod_file(options[:mode], name) \
        if options[:mode]
      FU.chown(options[:owner], options[:group], name) \
        if (options[:owner] || options[:group])
      f.write(content)
    end
  end

  def self.unlink(names)
    log(:debug, "rm_rf #{names}")
    FileUtils.rm_rf(names)
  end
end