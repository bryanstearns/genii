class Features::EtcHosts < Feature
  # Set up our /etc/hosts file, like:
  #   127.0.0.1 localhost
  #   [<ip> <hostname> <fqdn> <aliases...>]
  #   (ipv6 boilerplate)

  attr_accessor :aliases, :hostname, :fqdn

  def initialize(options={})
    super(options)
    self.aliases ||= {}
    self.hostname ||= `hostname`.strip
    self.fqdn ||= `hostname --fqdn`.strip

	build_address_mappings
  end

  def done?
    IO.read('/etc/hosts') == new_content
  end

  def apply
    File.open('/etc/hosts', 'w') do |f|
      f.write new_content
    end
  end

private
  def build_address_mappings
    @addresses = [] # we'll output in this order
    @address_to_names = Hash.new {|hash, key| hash[key] = [] }
    @name_to_address = {}
    add_mappings("127.0.0.1", "localhost")
    add_mappings(machine.local_ip, fqdn, hostname)
    aliases.each {|address, names| add_mappings(address, [names.split(' ')].flatten) }
  end

  def add_mappings(address, *names)
    return if names.empty?
    @addresses << address unless @addresses.include?(address)
    names.each do |name|
      unless @name_to_address[name]
        @address_to_names[address] << name
        @name_to_address[name] = address
      end
    end
  end

  def new_content
    lines = @addresses.map do |address|
      names = @address_to_names[address].join(' ')
      ("%-16s %s" % [address, names]) unless names.empty?
    end.flatten.join("\n")

    """#{genii_header("Hosts")}
#{lines}

# The following lines are desirable for IPv6 capable hosts
::1 ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts
"""
  end
end
