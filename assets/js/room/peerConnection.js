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
  videoPlayerWrapper.className = 'group relative w-full h-full';

  videoPlayer.id = id;
  videoPlayer.srcObject = stream;
  videoPlayer.autoplay = true;
  videoPlayer.playsInline = true;
  videoPlayer.muted = true;
  videoPlayer.className = 'peer-stream rounded-xl w-full h-full object-cover bg-black';
  videoPlayer.play().catch(e => console.log('Playback failed:', e));

  videoPlayerWrapper.appendChild(videoPlayer)

  return videoPlayerWrapper;
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
