defmodule Isaludic.GameStateTest do
  use ExUnit.Case, async: true

  alias Isaludic.Card
  alias Isaludic.GameState

  test "state survives a JSON round trip with the same shape" do
    state = GameState.new(jokers: 2)
    assert state["zombies"] |> Map.values() |> List.flatten() |> length() == 12
    assert state |> Jason.encode!() |> GameState.from_json(jokers: 2) == state
  end

  test "non-default phase, status and active card round trip" do
    [card | deck] = GameState.new(jokers: 2)["deck"]

    state =
      GameState.new(jokers: 2)
      |> Map.merge(%{"deck" => deck, "active_card" => card, "phase" => :kill, "status" => :win})

    assert state |> Jason.encode!() |> GameState.from_json(jokers: 2) == state
  end

  describe "placed_at" do
    test "round trips as [row, col]" do
      state = GameState.new(jokers: 2) |> Map.put("placed_at", [1, 2])
      assert state |> Jason.encode!() |> GameState.from_json(jokers: 2) == state
    end

    test "a save without placed_at, or with a bad one, falls back to a fresh state" do
      fresh = GameState.new(jokers: 2)
      without = fresh |> Map.delete("placed_at") |> Jason.encode!()
      bad = fresh |> Map.put("placed_at", [5, 0]) |> Jason.encode!()

      for json <- [without, bad] do
        assert GameState.from_json(json, jokers: 2)["placed_at"] == nil
        assert GameState.from_json(json, jokers: 2) != Jason.decode!(json)
      end
    end

    test "place_card records where the card landed, and only on a legal placement" do
      joker = %Card{value: 0, suit: nil, face: nil, is_joker: true}

      state =
        GameState.new(jokers: 2)
        |> Map.merge(%{"phase" => :place, "active_card" => joker})

      {placed, _killable} = GameState.place_card(state, {1, 2})
      assert placed["placed_at"] == [1, 2]
      assert placed["phase"] == :kill

      too_low = %Card{value: 1, suit: :heart, face: :ace, is_joker: false}
      target = %Card{value: 9, suit: :heart, face: nil, is_joker: false}

      illegal =
        state
        |> Map.put("active_card", too_low)
        |> put_in(["house", Access.at(0), Access.at(0)], target)

      {unchanged, []} = GameState.place_card(illegal, {0, 0})
      assert unchanged["placed_at"] == nil
    end
  end

  describe "in_line_with_placed?/2 and placed?/2" do
    test "match the placed cell's row and column" do
      state = GameState.new(jokers: 2) |> Map.put("placed_at", [1, 2])

      # placed at row 1, col 2
      assert GameState.placed?(state, {1, 2})
      refute GameState.placed?(state, {1, 1})

      for cell <- [{1, 0}, {1, 1}, {0, 2}, {2, 2}, {1, 2}] do
        assert GameState.in_line_with_placed?(state, cell), "expected #{inspect(cell)} in line"
      end

      for cell <- [{0, 0}, {2, 1}, {0, 1}] do
        refute GameState.in_line_with_placed?(state, cell),
               "expected #{inspect(cell)} not in line"
      end
    end

    test "nothing is in line before a card has been placed" do
      state = GameState.new(jokers: 2)
      refute GameState.in_line_with_placed?(state, {0, 0})
      refute GameState.placed?(state, {0, 0})
    end
  end

  test "missing, stale or corrupt JSON falls back to a fresh state" do
    for bad <- [
          nil,
          "nope",
          ~s({"deck":[],"zombies":[],"house":[]}),
          ~s({"deck":[],"zombies":{},"house":[]}),
          ~s({"deck":[{"value":"x"}],"zombies":{},"house":[]})
        ] do
      assert %{"zombies" => %{top: [_ | _]}} = GameState.from_json(bad, jokers: 2)
    end
  end

  describe "advance_game/1" do
    test "reveal draws the top card into play and moves to place" do
      state = GameState.new(jokers: 2)
      [top | rest] = state["deck"]

      assert %{"phase" => :place, "active_card" => ^top, "deck" => ^rest} =
               GameState.advance_game(state)
    end

    test "reveal with an empty deck ends the game, losing while zombies are alive" do
      state = GameState.new(jokers: 2) |> Map.put("deck", [])
      assert %{"phase" => :end, "status" => :lose} = GameState.advance_game(state)
    end

    test "reveal with an empty deck and no live zombies is a win" do
      state = GameState.new(jokers: 2) |> Map.put("deck", []) |> kill_all_zombies()
      assert %{"phase" => :end, "status" => :win} = GameState.advance_game(state)
    end

    test "place with a live zombie moves to kill" do
      state = GameState.new(jokers: 2) |> Map.put("phase", :place)
      assert GameState.advance_game(state)["phase"] == :kill
    end

    test "place with no live zombies wins" do
      state = GameState.new(jokers: 2) |> Map.put("phase", :place) |> kill_all_zombies()
      assert %{"phase" => :end, "status" => :win} = GameState.advance_game(state)
    end

    test "end re-evaluates the status from the zombies" do
      state = GameState.new(jokers: 2) |> Map.put("phase", :end)
      assert GameState.advance_game(state)["status"] == :lose
      assert state |> kill_all_zombies() |> GameState.advance_game() |> Map.get("status") == :win
    end
  end

  describe "reveal_zombie/2" do
    test "reveals exactly the chosen zombie and draws a card" do
      state = GameState.new(jokers: 2)
      [top | _] = state["deck"]

      result = GameState.reveal_zombie(state, {1, :left})

      revealed =
        for {pos, list} <- result["zombies"], z <- list, z.revealed?, do: {pos, z.index}

      assert revealed == [left: 1]
      assert %{"phase" => :place, "active_card" => ^top} = result
    end
  end

  describe "place_card/2" do
    # House is [col][row]; col 0 holds a 5♥ at row 0, col 1 a 5♠ at row 0.
    defp place_state(card) do
      GameState.new(jokers: 2)
      |> Map.merge(%{
        "phase" => :place,
        "active_card" => card,
        "house" => [[card(5, :heart), card(2, :club)], [card(5, :spade), card(2, :club)]]
      })
    end

    defp card(value, suit), do: %Card{value: value, suit: suit, face: nil, is_joker: false}
    defp joker, do: %Card{value: 0, suit: nil, face: nil, is_joker: true}

    defp placed?(card, pos) do
      {result, _killable} = GameState.place_card(place_state(card), pos)
      result["phase"] == :kill
    end

    test "same color: equal or higher is allowed, lower is not" do
      assert placed?(card(5, :diamond), {0, 0})
      assert placed?(card(6, :diamond), {0, 0})
      refute placed?(card(4, :diamond), {0, 0})
    end

    test "different color: equal or lower is allowed, higher is not" do
      assert placed?(card(5, :club), {0, 0})
      assert placed?(card(4, :club), {0, 0})
      refute placed?(card(6, :club), {0, 0})
    end

    test "a joker can be placed on anything" do
      assert placed?(joker(), {0, 0})
    end

    test "any card can be placed on a joker" do
      state = place_state(card(13, :club))
      state = put_in(state["house"], [[joker()], [card(5, :spade)]])
      assert {%{"phase" => :kill}, _killable} = GameState.place_card(state, {0, 0})
    end

    test "placing replaces the target at {row, col}, stored as house[col][row]" do
      placed = card(2, :diamond)
      {result, _killable} = GameState.place_card(place_state(placed), {1, 0})

      assert get_in(result["house"], [Access.at(0), Access.at(1)]) == placed
      assert get_in(result["house"], [Access.at(0), Access.at(0)]) == card(5, :heart)
      assert get_in(result["house"], [Access.at(1), Access.at(0)]) == card(5, :spade)
    end

    test "an illegal placement leaves the state unchanged and kills nothing" do
      state = place_state(card(4, :diamond))
      assert {^state, []} = GameState.place_card(state, {0, 0})
    end

    test "is ignored outside the place phase" do
      state = place_state(card(6, :diamond)) |> Map.put("phase", :reveal)
      assert {^state, []} = GameState.place_card(state, {0, 0})
    end
  end

  describe "advance_game/1 in the kill phase" do
    test "with an unrevealed zombie left, goes back to reveal without drawing" do
      state = GameState.new(jokers: 2) |> Map.put("phase", :kill)
      result = GameState.advance_game(state)

      assert result["phase"] == :reveal
      assert result["deck"] == state["deck"]
    end

    test "with everything revealed and a zombie alive, draws straight into place" do
      state =
        GameState.new(jokers: 2) |> Map.put("phase", :kill) |> reveal_all_zombies()

      [top | rest] = state["deck"]

      assert %{"phase" => :place, "active_card" => ^top, "deck" => ^rest} =
               GameState.advance_game(state)
    end

    test "with every zombie dead, wins" do
      state =
        GameState.new(jokers: 2)
        |> Map.put("phase", :kill)
        |> reveal_all_zombies()
        |> kill_all_zombies()

      assert %{"phase" => :end, "status" => :win} = GameState.advance_game(state)
    end
  end

  describe "kill_zombie/2" do
    test "kills exactly the chosen zombie, then moves on" do
      state = GameState.new(jokers: 2) |> Map.put("phase", :kill) |> reveal_all_zombies()
      result = GameState.kill_zombie(state, {2, :bottom})

      dead = for {pos, list} <- result["zombies"], z <- list, not z.alive?, do: {pos, z.index}
      assert dead == [bottom: 2]
      assert result["phase"] == :place
    end

    test "killing the last zombie wins the game" do
      state = GameState.new(jokers: 2) |> Map.put("phase", :kill) |> reveal_all_zombies()

      last_alive =
        state["zombies"]
        |> Map.values()
        |> List.flatten()
        |> Enum.reject(&(&1.pos == :top and &1.index == 0))
        |> Enum.map(&{&1.index, &1.pos})

      state =
        Enum.reduce(last_alive, state, fn {idx, pos}, acc ->
          kill_without_advancing(acc, idx, pos)
        end)

      assert %{"phase" => :end, "status" => :win} = GameState.kill_zombie(state, {0, :top})
    end
  end

  describe "valid_target/2" do
    defp targeting(card), do: GameState.new(jokers: 2) |> Map.put("active_card", card)

    test "same color needs an equal or higher card" do
      state = targeting(card(5, :heart))
      assert GameState.valid_target(state, card(5, :diamond))
      assert GameState.valid_target(state, card(4, :diamond))
      refute GameState.valid_target(state, card(6, :diamond))
    end

    test "different color needs an equal or lower card" do
      state = targeting(card(5, :heart))
      assert GameState.valid_target(state, card(5, :club))
      assert GameState.valid_target(state, card(6, :club))
      refute GameState.valid_target(state, card(4, :club))
    end

    test "nothing is a valid target without an active card" do
      state = GameState.new(jokers: 2)
      assert state["active_card"] == nil
      refute GameState.valid_target(state, card(5, :spade))
      refute GameState.valid_target(state, joker())
    end

    test "jokers match anything, in either direction" do
      assert GameState.valid_target(targeting(joker()), card(13, :club))
      assert GameState.valid_target(targeting(card(2, :heart)), joker())
    end
  end

  describe "place_card/2 killable zombies" do
    # Every zombie is a revealed, living jack and every house card is a 5♠, so any
    # zombie whose line the placed card is in would die (the other two 5s make 10).
    # That leaves adjacency as the only thing deciding who is killable.
    defp adjacency_state do
      jack = fn pos, idx ->
        %{
          card: %Card{value: 11, suit: :heart, face: :jack, is_joker: false},
          pos: pos,
          index: idx,
          alive?: true,
          revealed?: true
        }
      end

      zombies =
        Map.new([:top, :bottom, :left, :right], fn pos ->
          {pos, Enum.map(0..2, &jack.(pos, &1))}
        end)

      Map.merge(GameState.new(jokers: 2), %{
        "phase" => :place,
        "active_card" => card(5, :spade),
        "house" => for(_ <- 0..2, do: for(_ <- 0..2, do: card(5, :spade))),
        "zombies" => zombies
      })
    end

    defp killable_at(state, pos) do
      {_state, killable} = GameState.place_card(state, pos)
      Enum.sort(killable)
    end

    test "a corner kills the two zombies touching it" do
      assert killable_at(adjacency_state(), {0, 0}) == [{0, :left}, {0, :top}]
      assert killable_at(adjacency_state(), {2, 2}) == [{2, :bottom}, {2, :right}]
      assert killable_at(adjacency_state(), {0, 2}) == [{0, :right}, {2, :top}]
      assert killable_at(adjacency_state(), {2, 0}) == [{0, :bottom}, {2, :left}]
    end

    test "an edge kills the one zombie touching it" do
      assert killable_at(adjacency_state(), {0, 1}) == [{1, :top}]
      assert killable_at(adjacency_state(), {1, 0}) == [{1, :left}]
      assert killable_at(adjacency_state(), {1, 2}) == [{1, :right}]
      assert killable_at(adjacency_state(), {2, 1}) == [{1, :bottom}]
    end

    test "the center kills nothing" do
      assert killable_at(adjacency_state(), {1, 1}) == []
    end

    test "an adjacent zombie that is unrevealed or dead is not killable" do
      state = adjacency_state()

      state =
        put_in(
          state["zombies"][:top],
          List.update_at(state["zombies"][:top], 0, &%{&1 | revealed?: false})
        )

      state =
        put_in(
          state["zombies"][:left],
          List.update_at(state["zombies"][:left], 0, &%{&1 | alive?: false})
        )

      assert killable_at(state, {0, 0}) == []
      assert killable_at(state, {0, 1}) == [{1, :top}]
    end

    test "an adjacent zombie still needs the attack total and suits to work out" do
      state = adjacency_state()
      # the other two cards in the column add up to 4, not 10
      weak =
        put_in(
          state["house"],
          [[card(2, :club), card(2, :club), card(2, :club)]] ++ tl(state["house"])
        )

      # col 0, row 1 sits on the left edge: only the left zombie (a row attack, 5 + 5) is adjacent
      assert killable_at(weak, {1, 0}) == [{1, :left}]

      # col 0, row 0 is a corner: the top zombie's column attack is now 2 + 2, so only the left one dies
      assert killable_at(weak, {0, 0}) == [{0, :left}]
    end
  end

  defp map_zombies(state, fun) do
    update_in(state["zombies"], fn zombies ->
      Map.new(zombies, fn {pos, list} -> {pos, Enum.map(list, fun)} end)
    end)
  end

  defp kill_all_zombies(state), do: map_zombies(state, &%{&1 | alive?: false})

  defp reveal_all_zombies(state), do: map_zombies(state, &%{&1 | revealed?: true})

  defp kill_without_advancing(state, idx, pos),
    do: update_in(state, ["zombies", pos, Access.at(idx)], &%{&1 | alive?: false})
end
