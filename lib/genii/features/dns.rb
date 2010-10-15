class Features::Dns < Feature
  # Set up DNS
  attr_accessor :nameservers, :domain, :search

  def initialize(options={})
    super(options)
    self.domain ||= `hostname -d`.strip
    self.search = [search].flatten.compact
    self.search.unshift(domain) if (domain && !search.include?(domain))
  end

  def create_dependencies
    depends_on :file => {
                 :name => "/etc/resolv.conf",
                 :content => resolv_conf,
               }

    nothing_else_to_do!
  end

  def apply
    File.open("/etc/resolv.conf", 'w') do |f|
      f.write(resolv_conf)
    end
  end

  def resolv_conf
    """# ------------------------------------------------------
# DNS configuration written by genii -- DO NOT HAND EDIT
# ------------------------------------------------------
domain #{domain}
search #{search.join(' ')}
#{nameservers.map{|x| "nameserver #{x}" }.join("\n")}
options rotate
"""
  end
end