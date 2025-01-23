import { initListeners } from './interactionListeners'
import { joinChannel } from './channel'
import { createPeerConnection } from './peerConnection'
import { setupMedia } from './media'

const setupConnection = async () => {
  // Create peer connection first
  const peerConnection = await createPeerConnection();

  await setupMedia({ peerConnection });

  // Join channel after dummy stream is set up
  await joinChannel({ peerConnection });
}

export const Room = {
  async mounted() {
    try {
      initListeners({ setupConnection })

      await setupConnection()
    } catch (error) {
      console.error('Initialization error:', error);
    }
  },
};
