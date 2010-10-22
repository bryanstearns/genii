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
      FU.cp_r(source, name)
    else
      FU.mkdir_p(name)
    end
    FU.fix!(name,
            :dir_mode => dir_mode, :file_mode => mode,
            :owner => owner, :group => group) \
      if dir_mode || mode
  end

  def done?
    return false
  end
end
