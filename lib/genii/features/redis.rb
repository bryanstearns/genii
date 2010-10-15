class Features::Redis < Feature
  def create_dependencies
    depends_on :packages => {
                 :names => %w[redis-server]
               }
    depends_on :monit => {
                 :name => "redis",
                 :content => monit_content
               }

    nothing_else_to_do!
  end

private
  def monit_content
    """check process redis
  with pidfile /var/run/redis.pid
  start program = \"/etc/init.d/redis-server start\"
  stop program = \"/etc/init.d/redis-server stop\"
  if failed host 127.0.0.1 port 6379 then restart
  if 3 restarts within 5 cycles then timeout
  mode manual

"""
  end
end