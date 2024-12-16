defmodule OmegleClone.Repo do
  use Ecto.Repo,
    otp_app: :omegle_clone,
    adapter: Ecto.Adapters.Postgres
end
