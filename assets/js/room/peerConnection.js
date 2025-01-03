const pcConfig = {
  iceServers: [
    { urls: "stun:stun.l.google.com:19302" },
  ]
};

const updateVideoGrid = () => {
  const videoPlayerWrapper = document.getElementById('videoplayer-wrapper');
  const videoCount = videoPlayerWrapper.children.length;
  const columns = videoCount <= 1 ? 'grid-cols-1' :
                 videoCount <= 4 ? 'grid-cols-2' :
                 videoCount <= 9 ? 'grid-cols-3' :
                 videoCount <= 16 ? 'grid-cols-4' :
                 'grid-cols-5';

  videoPlayerWrapper.className = `
    w-full h-full grid gap-2 p-2 auto-rows-fr place-items-center grid-cols-1 sm:${columns}
  `;
}

const createPeerVideoEl = (event) => {
  const stream = event.streams[0]
  const id = stream.id;
  const videoPlayer = document.createElement('video');

  document.getElementById(id)?.remove()

  videoPlayer.id = id;
  videoPlayer.srcObject = stream;
  videoPlayer.autoplay = true;
  videoPlayer.playsInline = true;
  videoPlayer.muted = true;
  videoPlayer.className = 'peer-stream rounded-xl w-full h-full object-cover bg-black';

  videoPlayer.play().catch(e => console.log('Playback failed:', e));

  const videoPlayerWrapper = document.getElementById('videoplayer-wrapper');
  videoPlayerWrapper.appendChild(videoPlayer);

  return videoPlayer;
}

export const createPeerConnection = async () => {
  const pc = new RTCPeerConnection(pcConfig);

  pc.ontrack = (event) => {
    console.log(event)
    if (event.track.kind == 'video') {
      const videoPlayer = createPeerVideoEl(event);

      const videoPlayerWrapper = document.getElementById('videoplayer-wrapper');
      videoPlayerWrapper.appendChild(videoPlayer);

      updateVideoGrid();

      event.track.onended = (_) => {
        const videoPlayerWrapper = document.getElementById('videoplayer-wrapper');
        videoPlayerWrapper.removeChild(videoPlayer);

        updateVideoGrid();
      };
    }
  };

  return pc;
}
