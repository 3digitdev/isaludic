defmodule IsaludicWeb.Games.DeadCenterLiveTest do
  use IsaludicWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Isaludic.GameState

  defp mount_with(game_states) do
    conn =
      Plug.Test.init_test_session(build_conn(), %{})
      |> put_connect_params(%{"game_states" => game_states})

    live(conn, "/dead-center")
  end

  defp socket_state(view), do: :sys.get_state(view.pid).socket.assigns.state

  test "restores this game's saved state from its own localStorage slot" do
    saved = GameState.new(jokers: 2) |> GameState.advance_game()
    {:ok, view, _html} = mount_with(%{"dead-center" => Jason.encode!(saved)})

    assert saved["phase"] == :place
    assert socket_state(view) == saved
  end

  test "ignores other games' saved state" do
    other = GameState.new(jokers: 2) |> GameState.advance_game()
    {:ok, view, _html} = mount_with(%{"some-other-game" => Jason.encode!(other)})

    assert socket_state(view)["phase"] == :reveal
  end

  test "starts fresh when nothing is saved" do
    {:ok, view, _html} = mount_with(%{})
    assert socket_state(view)["phase"] == :reveal
  end

  test "stores state under this game's key on connect" do
    {:ok, view, _html} = mount_with(%{})

    assert_push_event(view, "store_game_state", %{
      game: "dead-center",
      state: %{"phase" => :reveal}
    })
  end

  test "the home link clears this game's state client-side, then navigates home" do
    {:ok, view, html} = mount_with(%{})

    # The click is a JS chain: dispatch phx:clear_game_state for this game, then push "home".
    assert html =~ "phx:clear_game_state"
    assert html =~ "dead-center"

    view |> element("span", "Isaludic") |> render_click()
    assert_redirect(view, "/")
  end

  describe "kill-phase support highlight" do
    defp kill_phase_state(placed_at),
      do: GameState.new(jokers: 2) |> Map.merge(%{"phase" => :kill, "placed_at" => placed_at})

    defp cyan_count(html), do: html |> String.split("!border-cyan-500") |> length() |> Kernel.-(1)

    test "lights up the placed card's row and column" do
      {:ok, _view, html} = mount_with(%{"dead-center" => Jason.encode!(kill_phase_state([0, 0]))})
      # row 0 and column 0 cross at the placed cell: 3 + 3 - 1, minus the placed cell itself
      assert cyan_count(html) == 4
    end

    test "is off for the center, where no zombie is adjacent" do
      {:ok, _view, html} = mount_with(%{"dead-center" => Jason.encode!(kill_phase_state([1, 1]))})
      assert cyan_count(html) == 0
      assert html =~ "!border-orange-400"
    end
  end
end
