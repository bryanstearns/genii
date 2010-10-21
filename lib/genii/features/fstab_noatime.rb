class Features::FstabNoatime < Feature
  # Mount our ext<n> filesystems with the "noatime" flag
  def done?
    read_fstab =~ /genii/
  end

  def apply
    updated = updated_fstab
    File.open('/etc/fstab', 'w') {|f| f.write(updated) }
    execute("mount -o noatime,remount,rw /dev/sda1")
  end

  def read_fstab
    @read_fstab ||= IO.read("/etc/fstab")
  end

  def updated_fstab
    genii_header("/etc/fstab with noatime") + read_fstab.gsub(%r{(ext\d\s+)defaults}, '\1noatime ')
  end
end