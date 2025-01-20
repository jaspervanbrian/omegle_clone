import { toggleMedia } from './media'
import { playAllPeerStreamsOnStartup } from './peerConnection'

let shouldModalScrollMessagesToBottom = true

const initLvConnection = (event) => {
  document.getElementById("my-username").innerText = `${event.detail.username} (You)`
}

const onModalOpen = (event) => {
  if (shouldModalScrollMessagesToBottom) {
    setTimeout(scrollDownMessageContainer, 200)
  }
}

const scrollDownMessageContainer = () => {
  const messagesContainer = document.getElementById("messages-container")
  messagesContainer.scrollTo(0, messagesContainer.scrollHeight);
}

const scrollOnNewMessage = (event) => {
  // Scroll down only for a certain height to allow backreading
  const messagesContainer = document.getElementById("messages-container")
  const pixelsBelowBottom =
    messagesContainer.scrollHeight - messagesContainer.clientHeight - messagesContainer.scrollTop;

  if (pixelsBelowBottom < messagesContainer.clientHeight * 0.4 || event.detail.scroll) {
    scrollDownMessageContainer()
  } else {
    const unreadMessagesEl = document.getElementById("unread-messages")
    const unreadMessagesBadgeEl = document.getElementById("unread-messages-count-badge")
    const newCount = parseInt(unreadMessagesEl.innerText) + 1

    unreadMessagesEl.innerText = newCount

    unreadMessagesBadgeEl.classList.remove('hidden')

    if (0 < messagesContainer.scrollHeight) {
      unreadMessagesBadgeEl.innerText = newCount
    }

    if (!shouldModalScrollMessagesToBottom) {
      document.getElementById("unread-messages-button-container").classList.remove('hidden')
    }
  }
}

const initializeMessageContainerScrollListener = () => {
  const messagesContainer = document.getElementById("messages-container")
  messagesContainer.scrollTo(0, messagesContainer.scrollHeight);

  messagesContainer.addEventListener("scroll", (event) => {
    const pixelsBelowBottom = event.target.scrollHeight - event.target.clientHeight - event.target.scrollTop;

    if (pixelsBelowBottom < messagesContainer.clientHeight * 0.1) {
      shouldModalScrollMessagesToBottom = true

      const unreadMessagesEl = document.getElementById("unread-messages")
      const unreadMessagesBadgeEl = document.getElementById("unread-messages-count-badge")
      unreadMessagesEl.innerText = 0
      unreadMessagesBadgeEl.innerText = 0

      document.getElementById("unread-messages-button-container").classList.add('hidden')
      unreadMessagesBadgeEl.classList.add('hidden')
    } else {
      shouldModalScrollMessagesToBottom = false
    }
  })
}

const initializeUnreadMessagesButtonListener = () => {
  const unreadMessagesButton = document.getElementById("unread-messages-button")

  unreadMessagesButton.addEventListener('click', scrollDownMessageContainer);
}

export const initListeners = () => {
  window.addEventListener('click', playAllPeerStreamsOnStartup)
  window.addEventListener('phx:init-lv-connection', initLvConnection)
  window.addEventListener('phx:new-message', scrollOnNewMessage)
  window.addEventListener('messages_modal:open', onModalOpen)

  initializeMessageContainerScrollListener()
  initializeUnreadMessagesButtonListener()
}

export const initMediaButtonsListeners = (peerConnection, channel) => {
  const cameraToggle = document.getElementById('camera-toggle');
  const micToggle = document.getElementById('mic-toggle');

  // Set up toggle button listeners
  cameraToggle.addEventListener('click', () => toggleMedia('video', peerConnection, channel));
  micToggle.addEventListener('click', () => toggleMedia('audio', peerConnection, channel));
}
