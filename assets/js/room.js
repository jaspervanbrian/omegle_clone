import { joinChannel } from './room/channel'
import { createPeerConnection } from './room/peerConnection'
import { setupMedia } from './room/media'

export const Room = {
  async mounted() {
    try {
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
