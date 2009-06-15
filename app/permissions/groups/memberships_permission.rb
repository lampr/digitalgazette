module Groups::MembershipsPermission

  def may_create_memberships?(group=@group)
    logged_in? and
    current_user.may?(:admin, group)
  end

  alias_method :may_join_memberships?, :may_create_memberships?

  # for now, there is only an edit ui for committees  
  def may_edit_memberships?(group=@group)
    may_create_memberships? and group.committee?
  end

  def may_list_memberships?(group=@group)
    if logged_in?
      current_user.may?(:admin, group) or
      current_user.member_of?(group) or
      group.profiles.visible_by(current_user).may_see_members? or
      group.committee? && may_read_membership?(group.parent)
    else
      group.profiles.public.may_see_members?
    end
  end

  %w(groups).each{ |action|
    alias_method "may_#{action}_memberships?".to_sym, :may_list_memberships?
  }

  def may_update_memberships?(group=@group)
    current_user.may?(:admin, group) and group.committee?
  end

  def may_destroy_memberships?(group = @group)
    logged_in? and
    current_user.direct_member_of?(group) and
    (group.network? or group.users.uniq.size > 1)
  end

  alias_method :may_leave_memberships?, :may_destroy_memberships?

end