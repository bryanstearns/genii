
class Features::Packages < Feature
  # A list of packages, or a single package
  # install by default, or remove if :uninstall
  attr_accessor :names, :uninstall, :debconf

  def initialize(options={})
    options[:names] ||= [options.delete(:name)].flatten
    super(options)
  end

  def done?
    !packages_with_wrong_installedness.any?
  end

  def apply
    execute("debconf-set-selections <<DEBCONF\n#{debconf}\nDEBCONF") \
      if debconf
    packages_to_change = packages_with_wrong_installedness.map(&:to_s).join(' ')
    execute("DEBIAN_FRONTEND=noninteractive apt-get " + \
            (uninstall ? 'remove' : 'install') + \
            " -y -q --force-yes #{packages_to_change}") \
      unless packages_to_change.empty?
    @packages_with_wrong_installedness = nil # invalidate the cache
  end

private
  def packages_with_wrong_installedness
    @packages_with_wrong_installedness ||= names.select do |name|
      !installed?(name) == !uninstall
    end
  end

  def installed?(package_name)
    cmd = execute("dpkg-query -f='${Package} ${Status}\n' --show #{package_name}",
                  :ignore_error => true)
    cmd.status == 0 && cmd.output !~ /not-installed/
  end
end
