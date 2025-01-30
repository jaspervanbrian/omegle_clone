defmodule OmegleCloneWeb.RoomLive.MessagesComponent do
  use OmegleCloneWeb, :html

  def component(assigns) do
    ~H"""
    <div class="flex flex-col flex-1 min-h-0 w-full h-full">
      <.header class="mb-4 border-b border-gray-300">Messages</.header>

      <div id="messages-container" class="relative flex-1 h-full min-h-0 overflow-y-scroll">
        <div class="w-full">
          <div class="flex flex-col gap-2.5">
            <%= if Enum.count(@messages) === 0 do %>
              <div class="flex w-full justify-center">
                <p class="mt-3 text-pretty text-md font-medium sm:text-lg">
                  No messages yet.
                </p>
              </div>
            <% end %>

            <div class="grid w-full" id="messages" phx-update="stream">
              <div
                :for={{dom_id, message} <- @messages}
                id={dom_id}
              >
                <%= case message.type do %>
                  <% :text_message -> %>
                    <%= if message.should_render_username do %>
                      <h5 class={["text-gray-700 text-xs leading-snug pb-1", message.peer_id === @peer_id && "text-right"]}>
                        {if message.peer_id === @peer_id, do: "You (#{message.username})", else: message.username}
                      </h5>
                    <% end %>

                    <div class={["flex w-full items-center group mb-2", message.peer_id === @peer_id && "flex-row-reverse"]}>
                      <div class={[
                        "px-3.5 py-2 rounded items-center gap-3 inline-flex focus:outline-none focus:ring-4 max-w-[80%]",
                        message.peer_id === @peer_id && "bg-purple-700 hover:bg-purple-800 focus:ring-purple-300 dark:bg-purple-600 dark:hover:bg-purple-700 dark:focus:ring-purple-900",
                        message.peer_id !== @peer_id && "justify-start bg-gray-100 hover:bg-gray-200 focus:ring-gray-300 dark:bg-gray-100 dark:hover:bg-gray-200 dark:focus:ring-gray-300" 
                      ]}>
                        <h5 class={[
                          "text-sm font-normal leading-snug",
                          message.peer_id === @peer_id && "text-white",
                          message.peer_id !== @peer_id && "text-gray-900"
                        ]}>
                          {message.body}
                        </h5>
                      </div>
                      <div class={[
                        "items-center hidden group-hover:inline-flex",
                        message.peer_id === @peer_id && "justify-start mr-2.5",
                        message.peer_id !== @peer_id && "justify-end ml-2.5"
                      ]}>
                        <h6 class="text-gray-500 text-xs font-normal leading-4 py-1" data-timestamp>
                        </h6>
                      </div>
                    </div>

                  <% :peer_info_message -> %>
                    <div class="flex w-full justify-center mb-2">
                      <p class="text-gray-400 text-pretty text-sm sm:text-md">
                        {message.body}
                      </p>
                    </div>
                <% end %>
              </div>
            </div>
          </div>
        </div>

        <div id="unread-messages-button-container" class="sticky flex bottom-3 w-full justify-center hidden" phx-update="ignore">
          <button
            id="unread-messages-button"
            class="items-center flex px-2 py-1 focus:outline-none bg-purple-700 hover:bg-purple-800 focus:ring-4 focus:ring-purple-300 dark:bg-purple-600 dark:hover:bg-purple-700 dark:focus:ring-purple-900 rounded-full shadow"
          >
            <.icon name="hero-arrow-down" class="text-white"/>
            <h3 class="text-white text-xs font-semibold leading-4 px-2"><span id="unread-messages">0</span> unread messages</h3>
          </button>
        </div>
      </div>
      <form phx-submit="send_message">
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
            <button class="items-center flex px-3 py-2 focus:outline-none bg-purple-700 hover:bg-purple-800 focus:ring-4 focus:ring-purple-300 dark:bg-purple-600 dark:hover:bg-purple-700 dark:focus:ring-purple-900 rounded-full shadow">
              <.icon name="hero-paper-airplane" class="text-white"/>
              <h3 class="text-white text-xs font-semibold leading-4 px-2 hidden sm:block">Send</h3>
            </button>
          </div>
        </div>
      </form>
    </div>
    """
  end
end
