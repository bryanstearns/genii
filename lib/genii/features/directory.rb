require 'find'

class Features::Directory < Features::File
  # Options we accept are the same as FileFeature's, plus:
  attr_accessor :dir_mode

  def initialize(options={})
    # fool Features::File's validation
    self.touch = true unless options[:source]
    super(options)
    self.dir_mode ||= 0755
  end

  def apply
    if source
      log(:debug, "Directory: copying #{source} to #{name}")
      FileUtils.cp_r(source, name)
    else
      log(:debug, "Directory: making #{name}")
      FileUtils.mkdir_p(name)
    end
    if dir_mode || mode
      Find.find(name) do |path|
        stat = File.stat(path)
        if stat.directory?
          if dir_mode
            log(:debug, "Directory: chmoding dir #{path} to 0#{"%o" % dir_mode}")
            FileUtils.chmod(dir_mode, path)
          end
        elsif mode
          new_mode = mode | (stat.executable? ? 0111 : 0)
          log(:debug, "Directory: chmoding file #{path} to 0#{"%o" % new_mode}")
          FileUtils.chmod(new_mode, path)
        end
      end
    end
    if (owner || group)
      log(:debug, "Directory: chowning-R #{name} to #{owner}:#{group}")
      FileUtils.chown_R(owner, group, name) 
    end
  end

  def done?
    return false
  end
end
