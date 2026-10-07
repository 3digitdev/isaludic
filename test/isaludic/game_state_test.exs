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

  defp map_zombies(state, fun) do
    update_in(state["zombies"], fn zombies ->
      Map.new(zombies, fn {pos, list} -> {pos, Enum.map(list, fun)} end)
    end)
  end

  defp kill_all_zombies(state), do: map_zombies(state, &%{&1 | alive?: false})
end
