const setUsername = (event) => {
  document.getElementById("my-username").innerText = `${event.detail.username} (You)`
}

export const init = () => {
  window.addEventListener('phx:init-lv-connection', setUsername)
}
