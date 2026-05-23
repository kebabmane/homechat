module MessagesHelper
  # Render a message body with lightweight Markdown and @mention highlighting.
  # Avoids external gems; keeps output sanitized.
  def render_message_body(text)
    return "" if text.blank?

    escaped = ERB::Util.html_escape(text.to_s)

    # Code blocks ``` ``` (multiline)
    escaped = escaped.gsub(/```\n?([\s\S]*?)\n?```/) do
      content = Regexp.last_match(1)
      "<pre class=\"hc-code\"><code>#{content}</code></pre>"
    end

    # Inline code `code`
    escaped = escaped.gsub(/`([^`]+)`/) { "<code class=\"hc-code-inline\">#{Regexp.last_match(1)}</code>" }

    # Bold **text**
    escaped = escaped.gsub(/\*\*([^*]+)\*\*/) { "<strong>#{Regexp.last_match(1)}</strong>" }

    # Italic *text* (naive; won’t conflict with bold after previous pass)
    escaped = escaped.gsub(/(?<!\*)\*([^*]+)\*(?!\*)/) { "<em>#{Regexp.last_match(1)}</em>" }

    # Links [text](url)
    escaped = escaped.gsub(/\[([^\]]+)\]\((https?:[^\s)]+)\)/) do
      label = Regexp.last_match(1)
      url   = Regexp.last_match(2)
      %(<a href="#{url}" target="_blank" rel="noopener" class="hc-link">#{label}</a>)
    end

    # Autolink bare URLs (http and https only)
    escaped = escaped.gsub(%r{(?<!href=")\bhttps?://[^\s<]+}) do |url|
      next url unless url =~ /\Ahttps?:\/\//i
      %(<a href="#{url}" target="_blank" rel="noopener" class="hc-link">#{url}</a>)
    end

    # Mentions @username (alphanumeric + underscore) → link to start DM
    escaped = escaped.gsub(/(^|\s)@([A-Za-z0-9_]{2,50})/) do
      prefix, name = Regexp.last_match(1), Regexp.last_match(2)
      href = start_dm_path(username: name) rescue "#"
      %(#{prefix}<a href="#{href}" class="hc-mention-link">@#{name}</a>)
    end

    # Preserve newlines
    escaped = escaped.gsub("\n", "<br>")

    allowed = %w[strong em a br pre code span]
    sanitize(escaped, tags: allowed, attributes: %w[href target rel class])
  end

  # Extract URLs from text for unfurling.
  delegate :extract_urls, to: :LinkPreviewService

  def render_link_previews(message)
    urls = extract_urls(message.content)
    return "".html_safe if urls.blank?

    # Render from cache only to avoid blocking page render on outbound HTTP.
    previews = urls.filter_map { |u| LinkPreviewService.cached_preview(u) }
    return "".html_safe if previews.blank?

    content_tag :div, class: "mt-2 space-y-2" do
      previews.map { |p|
        link_to p[:url], target: "_blank", rel: "noopener", class: "flex border border-gray-200 rounded-md p-3 hover:border-gray-300 hover:shadow-sm transition gap-3" do
          (image_tag(p[:image], class: "w-16 h-16 object-cover rounded hidden sm:block") if p[:image]).to_s.html_safe +
          content_tag(:div) do
            ((image_tag(p[:favicon], class: "inline-block w-4 h-4 mr-2 align-text-bottom") if p[:favicon]).to_s.html_safe) +
            content_tag(:div, p[:title].presence || p[:url], class: "text-sm text-gray-900") +
            (p[:description].present? ? content_tag(:div, truncate(p[:description], length: 140), class: "text-xs text-gray-600 mt-1") : "".html_safe)
          end
        end
      }.join.html_safe
    end
  end
end
