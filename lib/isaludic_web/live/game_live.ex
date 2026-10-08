defmodule IsaludicWeb.GameLive do
  use IsaludicWeb, :live_view

  def mount(_params, _session, socket) do
    socket =
      assign(
        socket,
        games: [
          %{
            name: "Dead Center",
            complexity: 3,
            weight: 2,
            footprint: 2,
            strategy: 3,
            tactics: 2,
            luck: 2,
            route: "dead-center",
            path: ~p"/dead-center"
          }
        ]
      )

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="w-full flex justify-between bg-slate-500 text-white top-0 left-0 right-0 p-2 font-bold text-2xl">
        Isaludic
      </div>
      <div class="w-full flex flex-col gap-4 mt-4 items-center">
        <span class="font-bold text-3xl">Pick your game</span>
        <div :for={game <- @games} class="flex gap-2 items-center">
          <.button navigate={game.path} text={game.name} />
          <button
            type="button"
            class="cursor-pointer"
            aria-label={"About #{game.name}"}
            phx-click={JS.show(to: "##{game.route}-info", display: "flex")}
          >
            <.icon name="hero-information-circle" class="size-6 mb-[2px]" />
          </button>
          <.modal id={"#{game.route}-info"} title={game.name}>
            <ul>
              <li>Complexity: {game.complexity}</li>
              <li>Weight: {game.weight}</li>
              <li>Footprint: {game.footprint}</li>
              <li>Strategy: {game.strategy}</li>
              <li>Tactics: {game.tactics}</li>
              <li>Luck: {game.luck}</li>
            </ul>
          </.modal>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
