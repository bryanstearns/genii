require 'munge'

class Features::File < Feature
  include FileTemplate
  include UsersAndGroups

  # Options we accept: one of these operation modes...
  MODES = :content, :source, :symlink_to, :touch, :unlink,
          :before, :after, :append, :replace
  attr_accessor *MODES
  # Plus these:
  attr_accessor :name, :erb, :group, :mode, :owner

  attr_accessor :munge_operation

  def initialize(options={})
    super(options)
    self.name = ::File.expand_path(name)

    abort "Just one of #{MODES.inspect} is required (#{self.inspect})" \
      unless MODES.map{|m| send(m) }.compact.size == 1

    if self.symlink_to
      oops = %w[owner group mode].select {|x| send(x)}
      abort "Can't specify #{oops.inspect} on symlinks" if oops.any?
      self.symlink_to = ::File.expand_path(symlink_to)
    else
      self.munge_operation = [:before, :after, :replace, :append].detect {|o| options[o]}
      self.source &&= RelativePath.find(source)
      self.owner ||= :root
      self.group ||= :root
      self.mode ||= 0644
    end
  end

  def describe_options
    # Shorten any file contents we were given
    result = options.dup
    result[:content] &&= result[:content].elided
    result
  end

  def apply
    if unlink
      do_unlink
      return
    end
    do_content
    do_mode
    do_owner
  end

  def done?
    if unlink
      unlink_done?
    else
      content_done? && mode_done? && owner_done?
    end
  end

private
  def stat
    @stat ||= ::File.exist?(name) and ::File.lstat(name)
  end

  def changed!
    @stat = nil
  end

  def unlink_done?
    # Normally, we'd check for the existance of the target file,
    # but we're probably deleting something installed by an earlier
    # feature, so just say we're not.
    false # !::File.exist?(name)
  end

  def content_done?
    if source
      FileCache.file_hash(name) == FileCache.file_hash(source)
    elsif touch
      ::File.exist?(name)
    elsif symlink_to
      ::File.symlink?(name) && \
        (::File.expand_path(::File.readlink(name)) == symlink_to)
    elsif content
      FileCache.file_hash(name) == FileCache.string_hash(content)
    elsif munge_operation
      munge(false) rescue false
    else
      false
    end
  end

  def mode_done?
    mode && mode == stat.try(:mode)
  end

  def owner_done?
    (!owner || (get_uid(owner) == stat.try(:uid))) && \
     (!group || (get_gid(group) == stat.try(:gid)))
  end

  def do_unlink
    return if unlink_done?
    log(:debug, "File: Removing-RF #{name}")
    FileUtils.rm_rf(name)
  end

  def do_content
    return if content_done?
    to_dir = ::File.dirname(name)
    unless ::File.directory?(to_dir)
      log(:debug, "File: mkdiring-P #{to_dir}")
      FileUtils.mkdir_p(to_dir)
    end
    if source
      if erb
        log(:debug, "File: template-copying #{source} to #{name} with #{erb.inspect}")
        copy_from_template(source, name, erb)
      else
        log(:debug, "File: copying #{source} to #{name}")
        FileUtils.copy(source, name)
      end
    elsif touch
      log(:debug, "File: touching #{name}")
      FileUtils.touch(name)
    elsif symlink_to
      log(:debug, "File: symlinking #{name} to #{symlink_to}")
      ::File.symlink(symlink_to, name)
    elsif content
      # Make sure we don't follow the symlink in writing our content
      FileUtils.rm_f(name) if ::File.symlink?(name)

      log(:debug, "File: writing content to #{name}")
      ::File.open(name, 'w') {|f| f.write(content) }
    elsif munge_operation
      munge
    end
    changed!
  end

  def do_mode
    if !mode_done?
      log(:debug, "File: chmoding #{name} to 0#{"%o" % mode}")
      FileUtils.chmod(mode, name)
      changed!
    end
  end

  def do_owner
    if !owner_done?
      log(:debug, "File: chowning #{name} to #{owner}:#{group}")
      FileUtils.chown(owner, group, name)
      changed!
    end
  end

  def munge(doit=true)
    log(:debug, "File: munging #{name}")
    original = IO.read(name)
    munge_options = send(munge_operation).dup
    munge_options.update(:mode => munge_operation, :input => original)
    munged = Munger.munge(munge_options)
    if doit
      File.open(name, 'w') {|f| f.write(munged)}
    else
      # just test whether we're done
      original == munged
    end
  end
end
