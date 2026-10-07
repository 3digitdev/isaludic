defmodule Isaludic.GameState do
  @moduledoc """
  Pure game state: a JSON-friendly map that the browser keeps in localStorage.
  """

  alias Isaludic.Card

  @type t :: %{String.t() => term()}
  # The house is arranged by COL, ROW for easiest rendering.
  @type house :: list(list(Card.t()))
  @type zombie_pos :: :top | :bottom | :left | :right
  @type zombie :: %{
          card: Card.t(),
          index: 0..2,
          pos: zombie_pos(),
          alive?: boolean(),
          revealed?: boolean()
        }
  @type phase :: :reveal | :place | :kill | :end
  @type status :: :win | :lose | nil

  @spec new(Keyword.t()) :: t()
  def new(deck_opts) do
    {faces, deck} =
      deck_opts
      |> Card.new_deck()
      |> Card.split_face_cards()

    pos = for p <- [:top, :bottom, :left, :right], i <- 0..2, do: {p, i}

    zombies =
      faces
      |> Enum.zip(pos)
      |> Enum.map(fn {card, {p, idx}} ->
        %{card: card, pos: p, index: idx, alive?: true, revealed?: false}
      end)
      |> Enum.group_by(& &1.pos)

    {house, deck} = Enum.split(deck, 9)
    house = Enum.chunk_every(house, 3)

    %{
      "deck" => deck,
      "zombies" => zombies,
      "house" => house,
      "active_card" => nil,
      # [row, col] of the most recently placed card (a list, since JSON can't hold tuples)
      "placed_at" => nil,
      "phase" => :reveal,
      "status" => nil
    }
  end

  @positions [:top, :bottom, :left, :right]
  @phases [:reveal, :place, :kill, :end]
  @statuses [:win, :lose]

  @doc """
  Builds state from the raw JSON string stored in localStorage (or nil).

  Saved state is decoded back into the same shape `new/1` produces (atom keys,
  `%Card{}` structs). Anything missing, stale or malformed gives a fresh state.
  """
  @spec from_json(String.t() | nil, Keyword.t()) :: t()
  def from_json(json, deck_opts \\ [])

  def from_json(json, deck_opts) when is_binary(json) do
    case Jason.decode(json) do
      {:ok,
       %{
         "deck" => deck,
         "zombies" => zombies,
         "house" => house,
         "active_card" => _,
         "placed_at" => _,
         "phase" => _,
         "status" => _
       } = saved}
      when is_list(deck) and is_map(zombies) and is_list(house) ->
        decode_state(saved)

      _ ->
        new(deck_opts)
    end
  rescue
    _ -> new(deck_opts)
  end

  def from_json(_, deck_opts), do: new(deck_opts)

  defp decode_state(saved) do
    %{
      "deck" => Enum.map(saved["deck"], &Card.from_map/1),
      "zombies" =>
        Map.new(saved["zombies"], fn {pos, list} ->
          {decode_enum(pos, @positions), Enum.map(list, &decode_zombie/1)}
        end),
      "house" => Enum.map(saved["house"], fn row -> Enum.map(row, &Card.from_map/1) end),
      "active_card" => saved["active_card"] && Card.from_map(saved["active_card"]),
      "placed_at" => decode_placed_at(saved["placed_at"]),
      "phase" => decode_enum(saved["phase"], @phases),
      "status" => saved["status"] && decode_enum(saved["status"], @statuses)
    }
  end

  defp decode_zombie(%{
         "card" => card,
         "pos" => pos,
         "index" => index,
         "alive?" => alive?,
         "revealed?" => revealed?
       })
       when is_integer(index) and is_boolean(alive?) do
    %{
      card: Card.from_map(card),
      pos: decode_enum(pos, @positions),
      index: index,
      alive?: alive?,
      revealed?: revealed?
    }
  end

  defp decode_placed_at(nil), do: nil

  defp decode_placed_at([row, col]) when row in 0..2 and col in 0..2, do: [row, col]

  defp decode_placed_at(other),
    do: raise(ArgumentError, "unexpected placed_at #{inspect(other)}")

  # Atoms don't survive JSON, so map strings back through an explicit list
  # (never String.to_atom/1 on client-controlled data). Raises on unknown values.
  defp decode_enum(string, allowed) do
    Enum.find(allowed, &(Atom.to_string(&1) == string)) ||
      raise ArgumentError, "unexpected value #{inspect(string)}"
  end

  def advance_game(state) do
    zombies = state["zombies"] |> Map.values() |> List.flatten()

    case state["phase"] do
      :reveal ->
        if state["deck"] == [] do
          Map.merge(state, %{"phase" => :end, "status" => end_state(zombies)})
        else
          {card, deck} = List.pop_at(state["deck"], 0)
          Map.merge(state, %{"phase" => :place, "active_card" => card, "deck" => deck})
        end

      :place ->
        if Enum.any?(zombies, & &1.alive?) do
          Map.put(state, "phase", :kill)
        else
          Map.merge(state, %{"phase" => :end, "status" => :win})
        end

      :kill ->
        cond do
          Enum.any?(zombies, &(not &1.revealed?)) ->
            Map.put(state, "phase", :reveal)

          Enum.any?(zombies, & &1.alive?) ->
            state |> Map.put("phase", :reveal) |> advance_game()

          true ->
            state |> Map.put("phase", :end) |> advance_game()
        end

      :end ->
        Map.put(state, "status", end_state(zombies))
    end
  end

  defp end_state(zombies), do: if(Enum.any?(zombies, & &1.alive?), do: :lose, else: :win)

  def valid_target(state, target) do
    card = state["active_card"]

    cond do
      card.is_joker or target.is_joker -> true
      Card.same_color?(card, target) -> card.value >= target.value
      true -> card.value <= target.value
    end
  end

  @spec place_card(t(), {0..2, zombie_pos()}) :: {t(), list({0..2, zombie_pos()})}
  def place_card(%{"phase" => :place, "active_card" => %Card{}} = state, {row, col}) do
    card = state["active_card"]
    target = get_in(state["house"], [Access.at(col), Access.at(row)])

    if valid_target(state, target) do
      state =
        state
        |> Map.merge(%{
          "house" => put_in(state["house"], [Access.at(col), Access.at(row)], card),
          "placed_at" => [row, col]
        })
        |> advance_game()

      {state, killable_zombies(state, {row, col})}
    else
      {state, []}
    end
  end

  def place_card(state, _pos), do: {state, []}

  defp killable_zombies(state, {row, col}) do
    zombies_by_coord =
      state["zombies"]
      |> Map.values()
      |> List.flatten()
      |> Map.new(&{{&1.index, &1.pos}, &1})

    col_atk_cards =
      state["house"]
      |> Enum.at(col)
      |> List.delete_at(row)

    row_atk_cards =
      state["house"]
      |> Enum.map(&Enum.at(&1, row))
      |> List.delete_at(col)

    col_zombies =
      [
        Map.get(zombies_by_coord, {col, :top}),
        Map.get(zombies_by_coord, {col, :bottom})
      ]
      |> Enum.filter(&kill?(&1, col_atk_cards))

    row_zombies =
      [
        Map.get(zombies_by_coord, {row, :left}),
        Map.get(zombies_by_coord, {row, :right})
      ]
      |> Enum.filter(&kill?(&1, row_atk_cards))

    Enum.map(col_zombies ++ row_zombies, &{&1.index, &1.pos})
  end

  defp kill?(%{alive?: false}, _), do: false
  defp kill?(%{revealed?: false}, _), do: false

  defp kill?(zombie, atk_cards) do
    suits = Enum.map(atk_cards, & &1.suit)

    # Jokers count as zero but that doesn't stop you from using a Joker + 10 to kill
    if Enum.sum_by(atk_cards, & &1.value) >= 10 do
      case zombie.card do
        %{face: :jack} ->
          true

        %{face: :queen, suit: suit} when suit in [:diamond, :heart] ->
          Enum.all?(suits, &(&1 in [:diamond, :heart, nil]))

        %{face: :queen, suit: suit} when suit in [:spade, :club] ->
          Enum.all?(suits, &(&1 in [:spade, :club, nil]))

        %{face: :king, suit: suit} ->
          Enum.all?(suits, &(&1 in [suit, nil]))
      end
    else
      false
    end
  end

  def in_line_with_placed?(%{"placed_at" => [placed_row, placed_col]}, {row, col}),
    do: row == placed_row or col == placed_col

  def in_line_with_placed?(_state, _cell), do: false

  def placed?(state, {row, col}), do: state["placed_at"] == [row, col]

  def reveal_zombie(state, {idx, pos}) do
    state
    |> update_in(["zombies", pos, Access.at(idx)], &%{&1 | revealed?: true})
    |> advance_game()
  end

  def kill_zombie(state, {idx, pos}) do
    state
    |> update_in(["zombies", pos, Access.at(idx)], &%{&1 | alive?: false})
    |> advance_game()
  end

  def update(state, values), do: Map.merge(state, values)

  @spec click(t()) :: t()
  def click(state), do: Map.update!(state, "clicks", &(&1 + 1))
end
