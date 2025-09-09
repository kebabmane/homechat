module ApplicationHelper
  def user_online?(user, window: 5.minutes)
    user.updated_at && user.updated_at > Time.current - window
  end

  def last_seen_text(user, window: 5.minutes)
    if user_online?(user, window: window)
      'Online'
    else
      user.updated_at ? "Last seen #{time_ago_in_words(user.updated_at)} ago" : 'Offline'
    end
  end
end
