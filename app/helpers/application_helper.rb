module ApplicationHelper
  AVATAR_COLORS = %w[bg-blue-500 bg-emerald-500 bg-fuchsia-500 bg-amber-500 bg-indigo-500 bg-rose-500 bg-cyan-500 bg-violet-500].freeze

  def avatar_for(user, size: 'h-10 w-10')
    initial = (user.username || '?')[0].upcase
    if user.respond_to?(:avatar) && user.avatar&.attached?
      image_tag user.avatar, alt: user.username, class: "#{size} rounded-full object-cover"
    else
      color = AVATAR_COLORS[user.username.to_s.hash % AVATAR_COLORS.length]
      content_tag :div, class: "#{size} #{color} rounded-full flex items-center justify-center text-white" do
        content_tag(:span, initial, class: 'font-medium')
      end
    end
  end
  def user_online?(user, window: 5.minutes)
    user.updated_at && user.updated_at > Time.current - window
  end

  def last_seen_text(user, window: 5.minutes)
    if user_online?(user, window: window)
      'Online'
    else
      user.updated_at ? "Active #{time_ago_in_words(user.updated_at)} ago" : 'Offline'
    end
  end
end
