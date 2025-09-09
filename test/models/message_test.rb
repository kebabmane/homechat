require "test_helper"

class MessageTest < ActiveSupport::TestCase
  test "requires content and associations" do
    user = create_user(username: "bob")
    owner = create_user(username: "owner3")
    ch = Channel.create!(name: "roomx", created_by: owner)
    msg = Message.new(content: "hello", user: user, channel: ch)
    assert msg.valid?
    msg.save!
    assert_equal "hello", msg.content
  end
end

