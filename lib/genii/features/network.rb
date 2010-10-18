require 'ipaddr'

class Features::Network < Feature
  # Interface is a hash configuring the available interfaces, eg:
  # :eth0 => {
  #   :ip => "10.0.0.1/24",
  #   :gateway => "10.0.0.2",
  # },
  # "eth0:0" => {
  #   :ip => "10.0.0.10/24",
  # }
  # :eth1 => :dhcp
  #
  # The loopback address will be done automatically

  attr_accessor :configuration

  def done?
    File.read("/etc/network/interfaces") =~ /genii/
  end

  def apply
    File.open("/etc/network/interfaces", 'w') do |f|
      f.write """#{genii_header("Network interfaces")}

auto lo
iface lo inet loopback

#{interface_details}
"""
    end
    execute("/etc/init.d/networking restart")
  end

  def interface_details
    auto_list = []
    interfaces = configuration.map do |interface, values|
      mode = values == :dhcp ? :dhcp : :static
      auto_list << interface unless values[:no_auto]
      values ||= {}
      results = []
      results << "iface #{interface} inet #{mode}"
      unless mode == :dhcp
        ip, netmask = ip_netmask(values[:ip])
        results << "  address #{ip}"
        results << "  netmask #{netmask}"
        results << "  gateway #{values[:gateway]}" if values[:gateway]
      end
      results << ""
      results
    end.flatten.join("\n")
    auto_list = "auto #{auto_list.join(' ')}" unless auto_list.empty?
    "#{auto_list}\n\n#{interfaces}"
  end

  def ip_netmask(ip)
    # Convert "10.0.0.1/17" to ["10.0.0.1", "255.255.128.0"]
    ip, net_bits = ip.split('/')
    bits = (net_bits || 24).to_i
    netmask = IPAddr.new((0xffffffff << (32 - bits)) & 0xffffffff,
                         Socket::AF_INET).to_s
    [ip, netmask]
  end
end
