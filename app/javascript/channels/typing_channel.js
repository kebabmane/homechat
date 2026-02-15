import consumer from "channels/consumer"

let subscription
let currentUserFilter = null

export function subscribeToTyping(channelId, currentUser, onTyping) {
  if (subscription) { subscription.unsubscribe() }
  currentUserFilter = currentUser ? currentUser.toLowerCase() : null
  subscription = consumer.subscriptions.create({ channel: "TypingChannel", id: channelId }, {
    received(data) {
      if (!data) return
      if (currentUserFilter && data.username && data.username.toLowerCase() === currentUserFilter) return
      onTyping?.(data)
    }
  })
}

export function broadcastTyping(channelId, typing = true) {
  if (!subscription) return
  try {
    subscription.perform("typing", { id: channelId, typing })
  } catch (_) {
    // no-op
  }
}

export function unsubscribeTyping() {
  if (subscription) {
    try {
      subscription.unsubscribe()
    } catch (_) {
      // ignore
    }
    subscription = null
  }
  currentUserFilter = null
}
