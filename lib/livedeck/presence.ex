defmodule Livedeck.Presence do
  use Phoenix.Presence,
    otp_app: :livedeck,
    pubsub_server: Livedeck.PubSub
end
