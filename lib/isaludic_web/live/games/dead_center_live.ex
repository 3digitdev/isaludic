defmodule IsaludicWeb.Games.DeadCenterLive do
  use IsaludicWeb, :live_view

  alias Isaludic.GameState

  # Key for this game's slot in the browser's localStorage (see assets/js/app.js).
  @game "dead-center"

  def mount(_params, _session, socket) do
    # Connect params (incl. localStorage contents) only exist once the socket is
    # connected; the initial static render uses the default state.
    state =
      if connected?(socket),
        do:
          GameState.from_json(get_in(get_connect_params(socket), ["game_states", @game]),
            jokers: 2
          ),
        else: GameState.new(jokers: 2)

    socket =
      assign(
        socket,
        state: state,
        active_target: nil,
        killable: []
      )

    socket = if connected?(socket), do: store_state(socket, state), else: socket

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <span
        phx-click={leave_game()}
        class="bg-slate-500 text-white font-bold text-2xl cursor-pointer absolute top-0 left-0 mt-2 ml-2"
      >
        Isaludic
      </span>
      <div class="w-full flex justify-center bg-slate-500 text-white p-2 font-bold text-2xl">
        Dead Center
      </div>
      <div class={[
        "w-full flex justify-center bg-cyan-600 text-white font-bold text-lg",
        @state["phase"] == :end && "bg-green-600",
        @state["status"] == :lose && "bg-red-600"
      ]}>
        <%= case @state["phase"] do %>
          <% :reveal -> %>
            Reveal a zombie
          <% :place -> %>
            Place your new card
          <% :kill -> %>
            Kill a zombie
          <% :end -> %>
            <%= if @state["status"] == :win do %>
              You win!
            <% else %>
              You lose.
            <% end %>
        <% end %>
      </div>
      <div class="flex flex-col w-full items-center gap-4 justify-center">
        <div class="flex gap-2 items-center mt-4">
          <.stack cards={@state["deck"]} facedown />
          <%= if @state["phase"] == :place do %>
            <.card card={@state["active_card"]} />
          <% else %>
            <.card_slot />
          <% end %>
        </div>
        <div class="flex flex-row items-center justify-center min-h-16 w-full">
          <div
            :if={@state["phase"] == :kill and @killable == []}
            class="flex flex-col gap-2 items-center"
          >
            <span class="text-red-500">No valid zombie targets!</span>
            <.button phx-click="next_card" text="Continue" />
          </div>
          <.button :if={@state["phase"] == :end} phx-click="new_game" text="New game" />
        </div>
        <div class="flex flex-col items-center gap-2 justify-center">
          <div class="flex items-center gap-2">
            <.card_slot class="!border-none" />
            <.render_zombie
              :for={z <- @state["zombies"].top}
              zombie={z}
              click={zombie_click_evt(@state, z, @killable)}
              phase={@state["phase"]}
              killable?={{z.index, z.pos} in @killable}
            />
            <.card_slot class="!border-none" />
          </div>
          <div class="flex items-center gap-2 justify-center">
            <div class="flex flex-col items-center gap-2">
              <.render_zombie
                :for={z <- @state["zombies"].left}
                zombie={z}
                click={zombie_click_evt(@state, z, @killable)}
                phase={@state["phase"]}
                killable?={{z.index, z.pos} in @killable}
              />
            </div>
            <div class="flex gap-2 rounded-3xl border border-3 border-amber-900 p-2">
              <div :for={col <- 0..2} class="flex flex-col items-center gap-2">
                <%= for {c, row} <- @state["house"] |> Enum.at(col) |> Enum.with_index() do %>
                  <% {class, click} = house_card_attrs(@state, c, {row, col}) %>
                  <.card
                    card={c}
                    class={class}
                    click={click}
                  />
                <% end %>
              </div>
            </div>
            <div class="flex flex-col items-center gap-2">
              <.render_zombie
                :for={z <- @state["zombies"].right}
                zombie={z}
                click={zombie_click_evt(@state, z, @killable)}
                phase={@state["phase"]}
                killable?={{z.index, z.pos} in @killable}
              />
            </div>
          </div>
          <div class="flex items-center gap-2">
            <.card_slot class="!border-none" />
            <.render_zombie
              :for={z <- @state["zombies"].bottom}
              zombie={z}
              click={zombie_click_evt(@state, z, @killable)}
              phase={@state["phase"]}
              killable?={{z.index, z.pos} in @killable}
            />
            <.card_slot class="!border-none" />
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :zombie, :any, required: true
  attr :click, :map, required: true
  attr :phase, :atom, required: true
  attr :killable?, :boolean, default: false

  defp render_zombie(assigns) do
    assigns =
      assign(
        assigns,
        :highlight,
        cond do
          assigns.phase == :reveal and not assigns.zombie.revealed? ->
            "!border-3 !border-amber-300"

          assigns.phase == :kill and assigns.killable? ->
            "!border-3 !border-red-500"

          true ->
            "!border-2 !border-lime-600"
        end
      )

    if assigns.zombie.alive? do
      ~H"""
      <.card
        card={assigns.zombie.card}
        class={[not @zombie.revealed? && "bg-lime-700/50", @highlight]}
        hide_value={not @zombie.revealed?}
        click={@click}
      />
      """
    else
      ~H"""
      <.card_slot><.icon name="hero-user" class="size-10 text-lime-600" /></.card_slot>
      """
    end
  end

  def handle_event("home", _, socket) do
    {:noreply, socket |> push_navigate(to: ~p"/")}
  end

  def handle_event("reveal_zombie", %{"index" => idx, "pos" => pos}, socket) do
    socket =
      if socket.assigns.state["phase"] == :reveal do
        coords = {String.to_integer(idx), String.to_existing_atom(pos)}
        state = GameState.reveal_zombie(socket.assigns.state, coords)
        update_socket_state(socket, state)
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_event("place_card", %{"row" => row, "col" => col}, socket) do
    {state, killable} =
      GameState.place_card(socket.assigns.state, {String.to_integer(row), String.to_integer(col)})

    {:noreply,
     socket
     |> assign(killable: killable)
     |> update_socket_state(state)}
  end

  def handle_event("next_card", _, socket) do
    state = GameState.advance_game(socket.assigns.state)
    {:noreply, update_socket_state(socket, state)}
  end

  def handle_event("kill_zombie", %{"index" => idx, "pos" => pos}, socket) do
    socket =
      if socket.assigns.state["phase"] == :kill do
        coords = {String.to_integer(idx), String.to_existing_atom(pos)}
        state = GameState.kill_zombie(socket.assigns.state, coords)
        update_socket_state(socket, state)
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_event("new_game", _, socket) do
    {:noreply, update_socket_state(socket, GameState.new(jokers: 2))}
  end

  def zombie_click_evt(state, zombie, killable) do
    cond do
      state["phase"] == :kill and zombie.alive? and zombie.revealed? and
          {zombie.index, zombie.pos} in killable ->
        %{event: "kill_zombie", index: zombie.index, pos: zombie.pos}

      state["phase"] == :reveal and zombie.alive? and not zombie.revealed? ->
        %{event: "reveal_zombie", index: zombie.index, pos: zombie.pos}

      true ->
        nil
    end
  end

  defp house_card_attrs(state, card, {row, col}) do
    cond do
      state["phase"] == :place and GameState.valid_target(state, card) ->
        {"!border-3 !border-amber-300", %{event: "place_card", row: row, col: col}}

      state["phase"] == :kill and GameState.placed?(state, {row, col}) ->
        {"!border-3 !border-orange-400", nil}

      state["phase"] == :kill and GameState.in_line_with_placed?(state, {row, col}) ->
        {"!border-3 !border-cyan-500", nil}

      true ->
        {"", nil}
    end
  end

  defp update_socket_state(socket, state) do
    socket
    |> assign(state: state)
    |> store_state(state)
  end

  # Leaving for the home screen wipes this game's saved state (client-side, so it
  # doesn't depend on the server's push_event surviving the navigation).
  defp leave_game,
    do: JS.dispatch("phx:clear_game_state", detail: %{game: @game}) |> JS.push("home")

  defp store_state(socket, state),
    do: push_event(socket, "store_game_state", %{game: @game, state: state})
end
