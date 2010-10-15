class Features::Fonts < Feature
  # Install one or more fonts.
  # :source can be a font filename or a directory whose
  # contents are fonts
  # :group is the name of a subfolder we put fonts into,
  # within /usr/share/fonts

  # TODO: Actually test this (I haven't used it, but wanted to capture the
  # essential cache-flushing step)

  attr_accessor :source, :group

  def initialize(options={})
    super(options)
    self.source &&= RelativePath(source)
    self.group ||= "opentype"
  end

  def create_dependencies
    depends_on :directory => {
                 :name => "/usr/share/fonts/#{group}"
               }
    copies.each do |source, name|
      depends_on :file => {
                   :name => name,
                   :source => source
                 }
    end
  end

  def done?
    false
  end

  def apply
    # Flush the font cache
    execute("fc-cache -f -v")
  end

  def copies
    if File.directory?(source)
      Dir.glob("#{source}/*").map do |f|
        [f, "/usr/share/fonts/#{group}/#{File.basename(f)}"]
      end
    else
      [[source, "/usr/share/fonts/#{group}/#{File.basename(source)}"]]
    end
  end
end
