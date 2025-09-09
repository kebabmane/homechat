import consumer from "channels/consumer"

let subscription

export function subscribeToTyping(channelId, onTyping) {
  if (subscription) { subscription.unsubscribe() }
  subscription = consumer.subscriptions.create({ channel: "TypingChannel", id: channelId }, {
    received(data) {
      onTyping?.(data)
    }
  })
}

export function broadcastTyping(channelId, username) {
  if (!subscription) return
  try {
    subscription.perform("typing", { id: channelId, username })
  } catch (_) {
    // no-op
  }
}

