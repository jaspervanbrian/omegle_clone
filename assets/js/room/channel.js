import { Socket, Presence } from 'phoenix';

const handleJoinError = (error) => {
  const errorText = error === 'peer_limit_reached' ?
    'Unable to join: Peer limit reached. Try again later' :
    'Unable to join the room';

  alert(errorText);
}

const getRoomId = () => {
  return window.location.pathname.split('/').filter(Boolean).pop()
}

const getClientId = () => {
  return document.getElementById("room").dataset.clientId
}

export const joinChannel = async ({ peerConnection }) => {
  const socket = new Socket('/socket');
  socket.connect();

  channel = socket.channel(`room:${getRoomId()}`, { client_id: getClientId() });

  const presence = new Presence(channel);
  presence.onSync(() => {
    console.log("Peer count: ", presence.list().length)
  });

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

  channel.on('add_peer_info', (payload) => {
    try {
      const username = presence.state[payload.peer_id]?.metas[0].username
      const usernameEl = document.createElement('p');
      const backgroundClasses = `group-hover:bg-gradient-to-r group-hover:from-gray-800 bg-gradient-to-r from-gray-800 sm:bg-none`
      usernameEl.id = `username-${payload.peer_id}`;
      usernameEl.className = `absolute bottom-0 left-0 p-2 sm:p-3 rounded-bl-xl text-xs text-white ${backgroundClasses}`;
      usernameEl.innerText = username

      document.getElementById(`stream-${payload.stream_id}`).appendChild(usernameEl)
    } catch (error) {
      console.error('Error loading peer info:', error);
    }
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
