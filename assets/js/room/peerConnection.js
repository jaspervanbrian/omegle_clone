const pcConfig = {
  iceServers: [
    { urls: "stun:stun.l.google.com:19302" },
  ]
};

const updateVideoGrid = () => {
  const streamsContainer = document.getElementById('streams-container');
  const videoCount = streamsContainer.children.length;
  const columns = videoCount <= 4 ? 'grid-cols-2' :
                 videoCount <= 9 ? 'grid-cols-3' :
                 videoCount <= 16 ? 'grid-cols-4' :
                 'grid-cols-5';

  streamsContainer.className = `
    w-full h-full grid gap-2 p-2 auto-rows-fr place-items-center grid-cols-1 sm:${columns}
  `;
}

const createPeerVideoEl = (event) => {
  const stream = event.streams[0]
  const id = stream.id;
  const videoPlayerWrapper = document.createElement('div')
  const videoPlayer = document.createElement('video');

  document.getElementById(id)?.remove()

  videoPlayerWrapper.id = `stream-${id}`;
  videoPlayerWrapper.className = 'group relative w-full h-full rounded-xl bg-black';

  videoPlayer.id = id;
  videoPlayer.srcObject = stream;
  videoPlayer.autoplay = true;
  videoPlayer.playsInline = true;
  videoPlayer.muted = false;
  videoPlayer.className = 'peer-stream rounded-xl w-full h-full object-cover bg-black';
  videoPlayer.play().catch(e => console.log('Playback failed:', e));

  videoPlayerWrapper.appendChild(videoPlayer)

  return videoPlayerWrapper;
}

export const playAllPeerStreamsOnStartup = async () => {
  const streamsContainer = document.getElementById('streams-container');
  const videoChildren = streamsContainer.querySelectorAll('.peer-stream');

  for (video of videoChildren) {
    video.muted = false;
    await video.play();
  }
}

export const addPeerMediaInfo = (presence, payload) => {
  const username = presence.state[payload.peer_id]?.metas[0].username
  const micStatus = presence.state[payload.peer_id]?.metas[0].audio_active
  const cameraStatus = presence.state[payload.peer_id]?.metas[0].video_active

  const usernameElWrapper = document.createElement('p');
  const backgroundClasses = `group-hover:bg-gradient-to-r group-hover:from-gray-800 bg-gradient-to-r from-gray-800 sm:bg-none`
  usernameElWrapper.className = `absolute bottom-0 left-0 p-2 sm:p-3 rounded-bl-xl text-xs text-white ${backgroundClasses}`;
  usernameElWrapper.innerText = username

  const usernameEl = document.createElement('span')
  usernameEl.id = `username-${payload.peer_id}`;

  const micStatusEl = document.getElementById('mic-status-icon').cloneNode(true)
  micStatusEl.id = `mic-status-${payload.peer_id}`
  micStatusEl.classList.toggle('bg-red-500', !micStatus)
  micStatusEl.classList.toggle('bg-green-500', micStatus)

  usernameElWrapper.appendChild(usernameEl)
  usernameElWrapper.appendChild(micStatusEl)

  const cameraStatusEl = document.getElementById('camera-status').cloneNode(true)
  cameraStatusEl.id = `camera-status-${payload.peer_id}`
  cameraStatus ? cameraStatusEl.classList.add('hidden') : cameraStatusEl.classList.remove('hidden')

  const peerStream = document.getElementById(`stream-${payload.stream_id}`)
  peerStream.dataset.peer = payload.peer_id
  peerStream.appendChild(cameraStatusEl)
  peerStream.appendChild(usernameElWrapper)
}

export const updatePeersInfo = (presenceState) => {
  for (let [peer, { metas }] of Object.entries(presenceState)) {
    const videoPlayerWrapperEl = document.querySelector(`[data-peer="${peer}"]`)

    if (videoPlayerWrapperEl) {
      const cameraStatusEl = document.getElementById(`camera-status-${peer}`)
      const micStatusEl = document.getElementById(`mic-status-${peer}`)
      const videoEl = videoPlayerWrapperEl.querySelector('video')

      if (cameraStatusEl) {
        const cameraStatus = metas[0].video_active
        cameraStatus ? cameraStatusEl.classList.add('hidden') : cameraStatusEl.classList.remove('hidden')
        cameraStatus ? videoEl.classList.remove('hidden') : videoEl.classList.add('hidden')
      }

      if (micStatusEl) {
        const micStatus = metas[0].audio_active
        micStatusEl.classList.toggle('bg-red-500', !micStatus)
        micStatusEl.classList.toggle('bg-green-500', micStatus)
      }
    }
  }
}

export const createPeerConnection = async () => {
  const pc = new RTCPeerConnection(pcConfig);

  pc.ontrack = (event) => {
    console.log(event)
    if (event.track.kind == 'video') {
      const videoPlayerWrapper = createPeerVideoEl(event);

      const streamsContainer = document.getElementById('streams-container');
      streamsContainer.appendChild(videoPlayerWrapper);

      updateVideoGrid();

      event.track.onended = (_) => {
        const streamsContainer = document.getElementById('streams-container');
        streamsContainer.removeChild(videoPlayerWrapper);

        updateVideoGrid();
      };
    }
  };

  return pc;
}
