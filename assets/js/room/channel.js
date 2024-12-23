import { Socket, Presence } from 'phoenix';

const handleJoinError = (error) => {
  const errorNode = document.getElementById('join-error-message');
  errorNode.innerText = error === 'peer_limit_reached' ?
    'Unable to join: Peer limit reached. Try again later' :
    'Unable to join the room';
  errorNode.classList.remove('hidden');
}

export const joinChannel = async ({ peerConnection }) => {
  const socket = new Socket('/socket');
  socket.connect();

  const queryString = window.location.search;
  const urlParams = new URLSearchParams(queryString);

  channel = urlParams.get('pro') ?
    socket.channel(`peer:hellooooo`) :
    socket.channel(`peer:signalling`);

  channel.on('sdp_offer', async (payload) => {
    try {
      await peerConnection.setRemoteDescription({ type: 'offer', sdp: payload.body });
      const answer = await peerConnection.createAnswer();
      await peerConnection.setLocalDescription(answer);
      channel.push('sdp_answer', { body: answer.sdp });
    } catch (error) {
      console.error('Error handling SDP offer:', error);
    }
  });

  channel.on('ice_candidate', (payload) => {
    try {
      peerConnection.addIceCandidate(JSON.parse(payload.body));
    } catch (error) {
      console.error('Error adding ICE candidate:', error);
    }
  });

  const presence = new Presence(channel);
  presence.onSync(() => {
    const peerCount = document.getElementById('viewercount');

    peerCount.innerText = presence.list().length;
  });

  peerConnection.onicecandidate = (event) => {
    if (event.candidate) {
      channel.push('ice_candidate', { body: JSON.stringify(event.candidate) });
    }
  };

  return channel.join()
    .receive('ok', () => console.log('Joined channel successfully'))
    .receive('error', handleJoinError);
}
