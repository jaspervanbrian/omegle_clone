defmodule OmegleCloneWeb.Utils do
  @moduledoc false

  def to_timestamp(datetime) do
    case datetime.hour do
      hour when hour === 0 ->
        "12:#{datetime.minute} AM"
      hour when hour === 12 ->
        "12:#{datetime.minute} PM"
      hour when hour > 12 ->
        "#{hour - 12}:#{datetime.minute} PM"
      hour ->
        "#{hour}:#{datetime.minute} AM"
    end
  end
end
