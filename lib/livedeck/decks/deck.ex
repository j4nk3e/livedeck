defmodule Livedeck.Decks.Deck do
  use Ecto.Schema
  import Ecto.Changeset

  schema "decks" do
    field :title, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(deck, attrs) do
    deck
    |> cast(attrs, [:title])
    |> validate_required([:title])
  end
end
