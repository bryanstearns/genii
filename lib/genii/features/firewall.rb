class Features::Firewall < Feature
  # Change the firewall settings; uses ufw, which manages iptables for us.
  #
  # Allow TCP on 5000:
  #   depends_on :firewall => { :tcp => 5000 }
  #
  # Allow TCP & UDP on 2000:
  #   depends_on :firewall => { :both => 3000 }
  #
  # Allow UDP only on 2000:
  #   depends_on :firewall => { :udp => 1000 }

  # Just make sure the firewall is running and denying anything not
  # specifically allowed (good to put in base_machine!):
  #   depends_on :firewall
  #
  attr_accessor :tcp, :udp, :both

  def create_dependencies
    depends_on :packages => {
                 :name => :ufw
               }
    depends_on :service => {
                 :name => :ufw
               }, :do_after => self
  end

  def done?
    enabled? && port_enabled?
  end

  def apply
    enable
    enable_port
  end

private
  def status
    @status ||= execute("ufw status").output rescue ""
  end

  def enabled?
    status =~ /^Status: active/
  end

  def port_enabled?
    port, mode = if both 
      [both, " "]
    elsif udp
      [udp, "/udp"]
    elsif tcp
      [tcp, "/tcp"]
    else
      return true
      nil
    end
    status =~ Regexp.new("^#{port}#{mode}\s+ALLOW")
  end

  def enable
    execute("ufw default deny")
    execute("ufw enable")
  end

  def enable_port
    if both
      execute("ufw allow #{both}")
    elsif udp
      execute("ufw allow #{udp}/udp")
    elsif tcp
      execute("ufw allow #{tcp}/tcp")
    end
  end
end
