class Features::AptUpdate < Feature
  def done?
    false
  end

  def apply
    execute("apt-get -y update && apt-get -y dist-upgrade")
  end
end