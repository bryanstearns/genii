require 'etc'

module UsersAndGroups
  # A lookup mechanism for user and group ids

  def get_uid(user_name)
    get_user_entry(user_name).try(:uid)
  end

  def get_user_entry(user_name)
    lookup_entry(user_name, :cached_users, :getpwent, :endpwent)
  end

  def get_gid(group_name)
    get_group_entry(group_name).try(:gid)
  end

  def get_group_entry(group_name)
    lookup_entry(group_name, :cached_groups, :getgrent, :endgrent)
  end

  def add_user_to_groups(group_names)
    group_names.each do |group_name|
      unless get_group_entry(group_name)
        log(:details, "Creating group #{group_name}")
        execute("groupadd -fr #{group_name}")
      end
    end
    log(:details, "Adding user #{login} to #{group_names.inspect}")
    execute("usermod -G #{group_names.join(',')} #{login}")

    @@cached_groups = nil # invalidate our cache when we add new users to groups
  end

private
  def cached_users
    @@cached_users ||= {}
  end
  def cached_groups
    @@cached_groups ||= {}
  end
  def cached_users=(new_users)
    @@cached_users = new_users
  end
  def cached_groups=(new_groups)
    @@cached_groups = new_groups
  end
  
  def lookup_entry(name, set, getter, ender)
    # If it's already a number, just return it
    return name if name.is_a? Numeric

    # Try to get it from what we've cached; reload the cache if it's not found
    the_easy_way(name, set) || the_hard_way(name, set, getter, ender)
  end

  def the_easy_way(name, set)
    # look it up in the right set
    send(set)[name.to_s]
  end

  def the_hard_way(name, set, getter, ender)
    # load the set, then look it up
    name_map = {}
    begin
      while (entry = Etc.send(getter)) do
        name_map[entry.name] = entry
      end
      send("#{set}=", name_map)
    ensure
      Etc.send(ender)
    end
    the_easy_way(name, set)
  end
end