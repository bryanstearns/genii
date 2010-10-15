class Features::Groups < Feature
  # Make sure this user is in these groups
  include UsersAndGroups

  attr_accessor :login, :groups

  def initialize(options={})
    options[:groups] ||= [options.delete(:group)].flatten
    super(options)
  end

  def done?
    groups.nil? || groups_not_a_member_of.empty?
  end

  def apply
    add_user_to_groups(groups_not_a_member_of)
  end

private
  def groups_not_a_member_of
    @groups_not_a_member_of ||= groups.select do |group|
      entry = get_group_entry(group)
      entry.nil? || !entry.mem.include?(:login)
    end
    @groups_not_a_member_of
  end
end
