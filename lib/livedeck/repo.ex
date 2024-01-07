defmodule Livedeck.Repo do
  use Ecto.Repo,
    otp_app: :livedeck,
    adapter: Ecto.Adapters.SQLite3
end
