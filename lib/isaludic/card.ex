defmodule Isaludic.Card do
  @suits [:spade, :club, :diamond, :heart]
  @faces [:jack, :queen, :king]
  @derive Jason.Encoder
  defstruct [:value, :suit, :face, :is_joker]

  @type value :: 1..14
  @type face :: :jack | :queen | :king | :ace | nil
  @type suits :: :spade | :club | :diamond | :heart
  @type t :: %__MODULE__{value: value(), suit: suits(), face: face(), is_joker: boolean()}
  @type deck :: [t()]

  @doc """
  Generates a new deck of 52 playing cards (+ optional jokers)

  Opts:
  - `ace_high`: boolean; whether Ace value is above king or not.  Default: `false`
  - `jokers`: integer; # of Joker cards to include.  usually 1 or 2.  Default: `0`
  """
  def new_deck(opts \\ []) do
    {low, high} =
      case opts[:ace_high] do
        true -> {2, 14}
        _ -> {1, 13}
      end

    deck =
      for suit <- @suits, value <- Enum.to_list(low..high), into: [] do
        cond do
          value in [1, 14] ->
            %__MODULE__{value: value, suit: suit, face: :ace, is_joker: false}

          value == 11 ->
            %__MODULE__{value: value, suit: suit, face: :jack, is_joker: false}

          value == 12 ->
            %__MODULE__{value: value, suit: suit, face: :queen, is_joker: false}

          value == 13 ->
            %__MODULE__{value: value, suit: suit, face: :king, is_joker: false}

          true ->
            %__MODULE__{value: value, suit: suit, face: nil, is_joker: false}
        end
      end

    (deck ++
       (Stream.cycle([%__MODULE__{value: 0, suit: nil, is_joker: true}])
        |> Stream.take(opts[:jokers] || 0)
        |> Enum.to_list()))
    |> Enum.shuffle()
  end

  @doc """
  Rebuilds a card from its decoded-JSON map. Atoms are restored via explicit
  lookups (never `String.to_atom/1`); raises on unknown values.
  """
  def from_map(%{"value" => value, "suit" => suit, "face" => face, "is_joker" => is_joker})
      when is_integer(value) and is_boolean(is_joker) do
    %__MODULE__{
      value: value,
      suit: decode_atom(suit, @suits),
      face: decode_atom(face, @faces ++ [:ace]),
      is_joker: is_joker
    }
  end

  defp decode_atom(nil, _allowed), do: nil

  defp decode_atom(string, allowed) do
    Enum.find(allowed, &(Atom.to_string(&1) == string)) ||
      raise ArgumentError, "unexpected value #{inspect(string)}"
  end

  def set_value(%{is_joker: true} = card, value, suit), do: %{card | value: value, suit: suit}
  def set_value(card, _value, _suit), do: card

  def clear_value(%{is_joker: true} = card), do: %{card | value: 0, suit: nil}
  def clear_value(card), do: card

  def color(%{suit: suit}) when suit in [:diamond, :heart], do: :red
  def color(%{suit: suit}) when suit in [:spade, :club], do: :black

  def same_color?(a, b), do: a.is_joker or b.is_joker or color(a) == color(b)

  def split_out(deck, values), do: Enum.split_with(deck, &(&1.value in values))

  def split_face_cards(deck), do: Enum.split_with(deck, &(&1.face in [:jack, :queen, :king]))

  def equal(a, b),
    do: a.suit == b.suit and a.value == b.value and a.is_joker == b.is_joker and a.face == b.face
end
