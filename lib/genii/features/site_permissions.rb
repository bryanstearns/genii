class Features::SitePermissions < Feature
  def create_dependencies
    depends_on :directory => {
                 :name => "/var/www",
                 :dir_mode => 0775,
                 :mode => 0664,
                 :owner => "www-data",
                 :group => "www-data"
               }
    nothing_else_to_do!
  end
end
