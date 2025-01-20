let localStream = undefined;
let dummyStream = undefined;
let isDummyStreamVideoActive = false;
let isDummyStreamAudioActive = false;

const createDummyAudioStream = () => {
  const audioContext = new AudioContext();
  const oscillator = audioContext.createOscillator();
  const dest = audioContext.createMediaStreamDestination();
  const gainNode = audioContext.createGain();

  // Set the gain to 0 to create silence
  gainNode.gain.value = 0;

  oscillator.connect(gainNode);
  gainNode.connect(dest);
  oscillator.start();

  const audioTrack = dest.stream.getAudioTracks()[0];
  if (audioTrack) {
    // Set a descriptive label for the silent audio track
    Object.defineProperty(audioTrack, 'label', { value: 'Silent Audio' });
  }

  return dest.stream;
}

// Create a dummy black video stream
const createDummyStream = () => {
  // Create video stream (same as before)
  const canvas = document.createElement('canvas');
  canvas.width = 640;
  canvas.height = 480;

  const ctx = canvas.getContext('2d');

  // Fill background
  ctx.fillStyle = 'black';
  ctx.fillRect(0, 0, canvas.width, canvas.height);

  ctx.save();

  const videoStream = canvas.captureStream(1);
  const videoTrack = videoStream.getVideoTracks()[0];
  if (videoTrack) {
    Object.defineProperty(videoTrack, 'label', { value: 'Placeholder Camera' });
  }

  // Create audio stream
  const audioStream = createDummyAudioStream();
  const audioTrack = audioStream.getAudioTracks()[0];

  // Combine video and audio tracks into one stream
  const combinedStream = new MediaStream();
  combinedStream.addTrack(videoTrack);
  combinedStream.addTrack(audioTrack);

  isDummyStreamVideoActive = true;
  isDummyStreamAudioActive = true;

  return combinedStream;
}

const updateToggleButtons = (isInitializing = false) => {
  const cameraToggle = document.getElementById('camera-toggle');
  const micToggle = document.getElementById('mic-toggle');

  const cameraToggleIconMuted = document.getElementById('camera-toggle-icon-muted');
  const cameraToggleIcon = document.getElementById('camera-toggle-icon');

  const micToggleIconMuted = document.getElementById('mic-toggle-icon-muted');
  const micToggleIcon = document.getElementById('mic-toggle-icon');

  const cameraStatus = document.getElementById('camera-status');
  const micStatusIcon = document.getElementById('mic-status-icon');

  if (isInitializing) {
    // Set initial state for both toggles
    cameraToggleIconMuted.classList.remove('hidden');
    cameraToggleIcon.classList.add('hidden');
    cameraToggle.classList.remove('bg-green-500', 'hover:bg-green-800');
    cameraToggle.classList.add('bg-red-500', 'hover:bg-red-800');

    micToggleIconMuted.classList.remove('hidden');
    micToggleIcon.classList.add('hidden');
    micToggle.classList.remove('bg-green-500', 'hover:bg-green-800');
    micToggle.classList.add('bg-red-500', 'hover:bg-red-800');

    cameraStatus.classList.remove('hidden')
    micStatusIcon.classList.add('bg-red-500')
    micStatusIcon.classList.remove('bg-green-500')

    return;
  }

  // Normal toggle update logic
  if (localStream) {
    const videoTrack = localStream.getVideoTracks()[0];
    const audioTrack = localStream.getAudioTracks()[0];

    const videoTrackEnabled = (videoTrack && videoTrack.enabled && !isDummyStreamVideoActive)
    if (videoTrackEnabled) {
      cameraToggleIconMuted.classList.add('hidden');
      cameraToggleIcon.classList.remove('hidden');
      cameraStatus.classList.add('hidden')
    } else {
      cameraToggleIconMuted.classList.remove('hidden');
      cameraToggleIcon.classList.add('hidden');
      cameraStatus.classList.remove('hidden')
    }
    cameraToggle.classList.toggle('bg-red-500', !videoTrackEnabled);
    cameraToggle.classList.toggle('hover:bg-red-800', !videoTrackEnabled);
    cameraToggle.classList.toggle('bg-green-500', videoTrackEnabled);
    cameraToggle.classList.toggle('hover:bg-green-800', videoTrackEnabled);

    const audioTrackEnabled = (audioTrack && audioTrack.enabled && !isDummyStreamAudioActive)
    if (audioTrackEnabled) {
      micToggleIconMuted.classList.add('hidden');
      micToggleIcon.classList.remove('hidden');
    } else {
      micToggleIconMuted.classList.remove('hidden');
      micToggleIcon.classList.add('hidden');
    }
    micToggle.classList.toggle('bg-red-500', !audioTrackEnabled);
    micToggle.classList.toggle('hover:bg-red-800', !audioTrackEnabled);
    micToggle.classList.toggle('bg-green-500', audioTrackEnabled);
    micToggle.classList.toggle('hover:bg-green-800', audioTrackEnabled);

    micStatusIcon.classList.toggle('bg-red-500', !audioTrackEnabled)
    micStatusIcon.classList.toggle('bg-green-500', audioTrackEnabled)
  }
}

// Initialize the dummy stream and add it to peer connection
const initializeDummyStream = async (peerConnection) => {
  const localVideoPlayer = document.getElementById('videoplayer-local');

  dummyStream = createDummyStream();

  if (localVideoPlayer) {
    localVideoPlayer.srcObject = dummyStream;
    localVideoPlayer.play().catch(e => console.log('Playback failed:', e));
    localVideoPlayer.classList.remove('hidden');
  }

  // Add both dummy tracks to peer connection
  if (peerConnection && dummyStream) {
    dummyStream.getTracks().forEach(track => {
      peerConnection.addTrack(track, dummyStream);
    });
  }

  // Update UI to reflect both camera and mic off state
  updateToggleButtons(true);
}

const removeVideoTracks = () => {
  localStream.getVideoTracks().forEach(track => {
    track.stop();
    localStream.removeTrack(track);
  });
}

const removeAudioTracks = () => {
  localStream.getAudioTracks().forEach(track => {
    track.stop();
    localStream.removeTrack(track);
  });
}

const toggleVideoMode = async (peerConnection, channel) => {
  const localVideoPlayer = document.getElementById('videoplayer-local');
  const hasVideoTrack = localStream?.getVideoTracks().length > 0;

  if (!hasVideoTrack || isDummyStreamVideoActive) {
    if (hasVideoTrack && isDummyStreamVideoActive) {
      removeVideoTracks();
    }

    try {
      isDummyStreamVideoActive = false;
      const stream = await navigator.mediaDevices.getUserMedia({ video: true });
      const videoTrack = stream.getVideoTracks()[0];

      if (!localStream) {
        // If no local stream exists, create one with the current dummy audio
        localStream = new MediaStream();

        if (dummyStream) {
          const dummyAudio = dummyStream.getAudioTracks()[0];
          if (dummyAudio) localStream.addTrack(dummyAudio);
        }
      }

      localStream.addTrack(videoTrack);

      if (localVideoPlayer) {
        localVideoPlayer.srcObject = localStream;
      }

      const sender = peerConnection.getSenders().find(s => s.track?.kind === 'video');

      if (sender) {
        await sender.replaceTrack(videoTrack);
      } else {
        peerConnection.addTrack(videoTrack, localStream);
      }

      channel.push('media_update', { video: true, audio: !isDummyStreamAudioActive });
    } catch (error) {
      isDummyStreamVideoActive = true;
      channel.push('media_update', { video: false, audio: !isDummyStreamAudioActive });
      console.error('Camera access error:', error);
      alert('Could not access camera. Please check your permissions.');
    }
  } else {
    // Switch back to dummy video
    isDummyStreamVideoActive = true;

    const dummyVideoTrack = dummyStream.getVideoTracks()[0];
    const sender = peerConnection.getSenders().find(s => s.track?.kind === 'video');

    if (sender) {
      await sender.replaceTrack(dummyVideoTrack);
    }

    removeVideoTracks();

    if (localVideoPlayer) {
      localVideoPlayer.srcObject = dummyStream;
    }

    channel.push('media_update', { video: false, audio: !isDummyStreamAudioActive });
  }
}

const toggleAudioMode = async (peerConnection, channel) => {
  const hasAudioTrack = localStream?.getAudioTracks().length > 0;

  if (!hasAudioTrack || isDummyStreamAudioActive) {
    if (hasAudioTrack && isDummyStreamAudioActive) {
      removeAudioTracks();
    }

    try {
      isDummyStreamAudioActive = false;

      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const audioTrack = stream.getAudioTracks()[0];

      if (!localStream) {
        // If no local stream exists, create one with the current dummy video
        localStream = new MediaStream();

        if (dummyStream) {
          const dummyVideo = dummyStream.getVideoTracks()[0];
          if (dummyVideo) localStream.addTrack(dummyVideo);
        }
      }

      localStream.addTrack(audioTrack);

      const sender = peerConnection.getSenders().find(s => s.track?.kind === 'audio');

      if (sender) {
        await sender.replaceTrack(audioTrack);
      } else {
        peerConnection.addTrack(audioTrack, localStream);
      }

      channel.push('media_update', { video: !isDummyStreamVideoActive, audio: true });
    } catch (error) {
      isDummyStreamAudioActive = true;
      channel.push('media_update', { video: !isDummyStreamVideoActive, audio: false });
      console.error('Microphone access error:', error);
      alert('Could not access microphone. Please check your permissions.');
    }
  } else {
    // Switch back to dummy audio
    isDummyStreamAudioActive = true;
    const dummyAudioTrack = dummyStream.getAudioTracks()[0];
    const sender = peerConnection.getSenders().find(s => s.track?.kind === 'audio');

    if (sender) {
      await sender.replaceTrack(dummyAudioTrack);
    }

    removeAudioTracks();

    channel.push('media_update', { video: !isDummyStreamVideoActive, audio: false });
  }
}

export const toggleMedia = async (type, peerConnection, channel) => {
  if (type === 'video') {
    await toggleVideoMode(peerConnection, channel)
  } else { // Audio toggle
    await toggleAudioMode(peerConnection, channel)
  }

  updateToggleButtons();
}

export const getMediaStatus = () => {
  return {
    video: !isDummyStreamVideoActive,
    audio: !isDummyStreamAudioActive
  }
}

export const setupMedia = async ({ peerConnection }) => {
  // Initialize dummy stream before joining channel
  await initializeDummyStream(peerConnection);
}
