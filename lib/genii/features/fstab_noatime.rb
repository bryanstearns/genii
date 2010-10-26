class Features::FstabNoatime < Feature
  # Mount our ext<n> filesystems with the "noatime" flag
  def done?
    read_fstab =~ /genii/
  end

  def apply
    updated = updated_fstab
    FU.write!('/etc/fstab', updated)
    execute("mount -o noatime,remount,rw #{slash_device}")
  end

  def read_fstab
    @read_fstab ||= IO.read("/etc/fstab")
  end

  def slash_device
    %r[^(/dev/\S+) on / ].match(execute('mount').output)[1]
  end

  def updated_fstab
    genii_header("/etc/fstab with noatime") + \
      read_fstab.gsub(%r{(ext\d\s+)defaults}, '\1noatime ')
  end
end