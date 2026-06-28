require "test_helper"

class MessagesHelperTest < ActionView::TestCase
  test "html_escape prevents script injection" do
    malicious = '<script>alert("xss")</script>'
    result = render_message_body(malicious)
    assert_not result.include?("<script>")
    assert result.include?("&lt;script&gt;")
  end

  test "sanitize neutralizes javascript: URLs" do
    payload = '[click](javascript:alert("xss"))'
    result = render_message_body(payload)
    # Should not contain a live href with javascript: scheme
    assert_not result.match?(/href=["']javascript:/i)
  end

  test "sanitize neutralizes onerror attributes" do
    payload = "**bold**<img src=x onerror=alert(1)>"
    result = render_message_body(payload)
    # After html_escape, <img> becomes &lt;img&gt; — no live tag
    assert_not result.include?("<img")
    assert result.include?("<strong>bold</strong>")
  end

  test "angle brackets are preserved as entities" do
    payload = "5 < 10 and 10 > 5"
    result = render_message_body(payload)
    assert result.include?("&lt;")
    assert result.include?("&gt;")
  end

  test "allows safe markdown formatting" do
    text = "Hello **world** and *italic*"
    result = render_message_body(text)
    assert result.include?("<strong>world</strong>")
    assert result.include?("<em>italic</em>")
  end

  test "allows safe links" do
    text = "Visit [example](https://example.com)"
    result = render_message_body(text)
    assert result.include?('<a href="https://example.com"')
  end

  test "mention links are rendered safely" do
    text = "Hey @alice check this"
    result = render_message_body(text)
    assert result.include?("@alice")
    assert result.include?(%(href="#{new_dm_path(username: "alice")}"))
  end
end
