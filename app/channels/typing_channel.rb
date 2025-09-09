class TypingChannel < ApplicationCable::Channel
  def subscribed
    stream_from stream_name
  end

  def typing(data)
    ActionCable.server.broadcast(stream_name, { username: data["username"] })
  end

  private

  def stream_name
    "typing:#{params[:id]}"
  end
end

