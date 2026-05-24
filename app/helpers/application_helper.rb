module ApplicationHelper
  AVATAR_COLORS = %w[bg-blue-500 bg-emerald-500 bg-fuchsia-500 bg-amber-500 bg-indigo-500 bg-rose-500 bg-cyan-500 bg-violet-500].freeze

  def homechat_base_path
    request.script_name.presence || Rails.application.config.relative_url_root.to_s.presence || ""
  end

  def homechat_action_cable_meta_tag
    tag.meta name: "action-cable-url", content: "#{homechat_base_path}/cable"
  end

  def homechat_javascript_importmap_tags(entry_point = "application", importmap: Rails.application.importmap)
    cache_key = [ entry_point, homechat_base_path.presence || "root" ].join(":")

    safe_join [
      javascript_inline_importmap_tag(importmap.to_json(resolver: self, cache_key: "json:#{cache_key}")),
      homechat_javascript_importmap_module_preload_tags(importmap, entry_point:, cache_key: "preload:#{cache_key}"),
      javascript_import_module_tag(entry_point)
    ], "\n"
  end

  def homechat_javascript_importmap_module_preload_tags(importmap = Rails.application.importmap, entry_point: "application", cache_key: nil)
    packages = importmap.preloaded_module_packages(resolver: self, entry_point:, cache_key: cache_key || entry_point)
    content_security_policy_nonce = request&.content_security_policy_nonce

    safe_join(packages.map do |path, package|
      tag.link rel: "modulepreload", href: path, nonce: content_security_policy_nonce, integrity: package.integrity
    end, "\n")
  end

  def avatar_for(user, size: "h-10 w-10")
    username = user&.username.to_s.presence || "Unknown"
    initial = username[0]&.upcase || "?"
    alt_text = "#{username}'s avatar"
    if user&.respond_to?(:avatar) && user.avatar&.attached?
      image_tag user.avatar, alt: alt_text, class: "#{size} rounded-full object-cover"
    else
      color = AVATAR_COLORS[username.hash % AVATAR_COLORS.length]
      content_tag :div, class: "#{size} #{color} rounded-full flex items-center justify-center text-white", role: "img", 'aria-label': alt_text, title: username do
        content_tag(:span, initial, class: "font-medium", 'aria-hidden': "true")
      end
    end
  end
  def user_online?(user, window: 5.minutes)
    return false unless user&.updated_at

    user.updated_at > Time.current - window
  end

  def last_seen_text(user, window: 5.minutes)
    return "Offline" unless user

    if user_online?(user, window: window)
      "Online"
    else
      user.updated_at ? "Active #{time_ago_in_words(user.updated_at)} ago" : "Offline"
    end
  end

  # WhatsApp-style relative timestamp for messages
  # Returns: "2 min ago" / "Today 2:30 PM" / "Yesterday 2:30 PM" / "Mon 2:30 PM" / "Jan 5 2:30 PM"
  def chat_timestamp(time)
    return "" unless time

    now = Time.current
    diff = now - time

    if diff < 1.minute
      "Just now"
    elsif diff < 1.hour
      "#{ (diff / 60).to_i } min ago"
    elsif time.to_date == now.to_date
      "Today #{time.strftime('%-I:%M %p')}"
    elsif time.to_date == (now - 1.day).to_date
      "Yesterday #{time.strftime('%-I:%M %p')}"
    elsif time > now.beginning_of_week
      time.strftime("%a %-I:%M %p")
    else
      time.strftime("%b %-d %-I:%M %p")
    end
  end

  def e2ee_icon(class_name: "w-3 h-3", tone_class: "text-emerald-600", label: nil, aria_hidden: true)
    wrapper_attrs = { class: "inline-flex items-center #{tone_class}".strip }
    if label.present?
      wrapper_attrs[:role] = "img"
      wrapper_attrs[:'aria-label'] = label
    elsif aria_hidden
      wrapper_attrs[:'aria-hidden'] = "true"
    end

    content_tag(:span, wrapper_attrs) do
      tag.svg(class: class_name, fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do
        tag.path(
          'stroke-linecap': "round",
          'stroke-linejoin': "round",
          'stroke-width': "2",
          d: "M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"
        )
      end
    end
  end

  def e2ee_badge(text: "End-to-end encrypted", class_name: nil)
    classes = [
      "inline-flex items-center gap-1 rounded-full border border-emerald-200 bg-emerald-50 px-2 py-0.5 text-[11px] font-medium text-emerald-700",
      class_name
    ].compact.join(" ")

    content_tag(:span, class: classes, 'aria-label': text) do
      safe_join([
        e2ee_icon(class_name: "w-3 h-3", tone_class: "", aria_hidden: true),
        content_tag(:span, text)
      ])
    end
  end

  def e2ee_inline(text: "End-to-end encrypted", class_name: "inline-flex items-center gap-1 text-emerald-700")
    content_tag(:span, class: class_name) do
      safe_join([
        e2ee_icon(class_name: "w-3.5 h-3.5", tone_class: "", aria_hidden: true),
        content_tag(:span, text)
      ])
    end
  end

  def status_dot(kind: :ok, class_name: "")
    tone = case kind.to_sym
    when :ok
             "status-dot--ok"
    when :warn
             "status-dot--warn"
    else
             "status-dot--neutral"
    end
    content_tag(:span, nil, class: [ "status-dot", tone, class_name ].reject(&:blank?).join(" "), 'aria-hidden': "true")
  end

  def status_with_dot(text, kind: :ok, class_name: "")
    content_tag(:span, class: [ "inline-flex items-center gap-2", class_name ].reject(&:blank?).join(" ")) do
      safe_join([ status_dot(kind: kind), content_tag(:span, text) ])
    end
  end
end
