import { init } from './init'
import { joinChannel } from './channel'
import { createPeerConnection } from './peerConnection'
import { setupMedia } from './media'

export const Room = {
  async mounted() {
    try {
      init()

      // Create peer connection first
      const peerConnection = await createPeerConnection();

      await setupMedia({ peerConnection });

      // Join channel after dummy stream is set up
      await joinChannel({ peerConnection });
    } catch (error) {
      console.error('Initialization error:', error);
    }
  },
};
