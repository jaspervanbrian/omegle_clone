defmodule OmegleCloneWeb.RoomLive.MessagesComponent do
  use OmegleCloneWeb, :html

  def component(assigns) do
    ~H"""
    <div class="flex flex-col flex-1 min-h-0 w-full h-full">
      <.header class="mb-4 border-b border-gray-300">Messages</.header>

      <div class="flex-1 h-full min-h-0 overflow-y-scroll">
        <div class="w-full">
          <div class="flex gap-2.5">
            <div class="grid w-full">
              <h5 class="text-gray-900 text-sm font-semibold leading-snug pb-1">Shanay cruz</h5>
              <div class="flex w-full items-center group mb-2">
                <div class="px-3.5 py-2 bg-gray-100 rounded justify-start items-center gap-3 inline-flex max-w-[80%]">
                  <h5 class="text-gray-900 text-sm font-normal leading-snug">Guts, I need a review of work. Are you ready?</h5>
                </div>
                <div class="justify-end items-center ml-2.5 hidden group-hover:inline-flex">
                  <h6 class="text-gray-500 text-xs font-normal leading-4 py-1">05:14 PM</h6>
                </div>
              </div>
            </div>
          </div>
          <div class="flex gap-2.5">
            <div class="grid w-full">
              <h5 class="text-right text-gray-900 text-sm font-semibold leading-snug pb-1">You</h5>
              <div class="flex flex-row-reverse w-full items-center group mb-2">
                <div class="px-3.5 py-2 bg-indigo-600 rounded items-center gap-3 inline-flex max-w-[80%]">
                  <h5 class="text-white text-sm font-normal leading-snug">Yes, let’s see, send your work here</h5>
                </div>
                <div class="justify-start items-center mr-2.5 hidden group-hover:inline-flex">
                  <h6 class="text-gray-500 text-xs font-normal leading-4 py-1">05:14 PM</h6>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
      <.form phx-submit="send_message">
        <div class="w-full pl-3 pr-1 py-1 rounded-3xl border border-gray-200 items-center gap-2 inline-flex justify-between">
          <div class="flex items-center gap-2 w-full">
            <input
              name="message"
              value={@message}
              phx-change="message_changed"
              class="w-full text-black text-xs font-medium leading-4 focus:outline-none"
              placeholder="Type here..."
              required
            />
          </div>
          <div class="flex items-center gap-2">
            <button class="items-center flex px-3 py-2 bg-indigo-600 rounded-full shadow">
              <.icon name="hero-paper-airplane" class="text-white"/>
              <h3 class="text-white text-xs font-semibold leading-4 px-2">Send</h3>
            </button>
          </div>
        </div>
      </.form>
    </div>
    """
  end
end
