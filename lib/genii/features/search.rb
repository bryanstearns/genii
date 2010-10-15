class Features::Search < Feature
  # Search with Sphinx
  # For now, we're just using the package, which is 0.9.8 or so;
  # 1.10 is in beta and brings real-time indexing, so updating soon
  # would be good (but more complicated to set up)

  def create_dependencies
    depends_on :packages => { :name => sphinxsearch }

    depends_on :monit => {
                 :name => "exim4",
                 :content => monit_content
               },
               :do_after => self

    depends_on :service => { :name => :sphinx },
               :do_after => self

    nothing_else_to_do!
  end

private
  def monit_content
    """check process sphinx
  with pidfile /var/run/sphinx.pid
  start program = \"/etc/init.d/sphinx start\"
  stop program = \"/etc/init.d/sphinx stop\"
  if failed host 127.0.0.1 port 25 protocol smtp then restart
  if 3 restarts within 5 cycles then timeout
  mode manual
"""
  end
end
