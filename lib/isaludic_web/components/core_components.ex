defmodule IsaludicWeb.CoreComponents do
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash
        id="welcome-back"
        kind={:info}
        phx-mounted={show("#welcome-back") |> JS.remove_attribute("hidden")}
        hidden
      >
        Welcome Back!
      </.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class="fixed top-4 right-4 z-50"
      {@rest}
    >
      <div class={[
        "flex items-center gap-2 rounded-lg border p-4 text-sm shadow-lg w-80 sm:w-96 max-w-80 sm:max-w-96 text-wrap",
        @kind == :info && "bg-sky-100 border-sky-300 text-sky-900",
        @kind == :error && "bg-red-100 border-red-300 text-red-900"
      ]}>
        <.icon :if={@kind == :info} name="hero-information-circle" class="size-5 shrink-0" />
        <.icon :if={@kind == :error} name="hero-exclamation-circle" class="size-5 shrink-0" />
        <div>
          <p :if={@title} class="font-semibold">{@title}</p>
          <p>{msg}</p>
        </div>
        <div class="flex-1" />
        <button type="button" class="group self-start cursor-pointer" aria-label="close">
          <.icon name="hero-x-mark" class="size-5 opacity-40 group-hover:opacity-70" />
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renders a button with navigation support.

  ## Examples

      <.button text="Send!" />
      <.button phx-click="go" text="Send!" />
      <.button navigate={~p"/"} text="Home" />
  """
  attr :text, :string, required: true
  attr :rest, :global, include: ~w(href navigate patch method download name value disabled)
  attr :class, :any
  slot :inner_block, required: false

  def button(%{rest: rest} = assigns) do
    assigns =
      assign_new(assigns, :class, fn ->
        "inline-flex items-center justify-center px-4 cursor-pointer"
      end)

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <div class="w-fit perspective-500 translate-y-[2px]">
        <div class="bg-gray-800 border-x-3 border-t-0 border-b-3 border-gray-800 rounded-sm rotate-x-[30deg] origin-top">
          <.link
            class={[
              "h-8 rounded-sm [box-shadow:inset_0_2px_0_rgba(255,255,255,0.35),inset_0_-2px_0_rgba(0,0,0,0.15),0_4px_0_rgba(151,60,0)] border-none bg-amber-500 -translate-y-1 active:-translate-y-0 active:[box-shadow:inset_0_2px_0_rgba(255,255,255,0.35),inset_0_-2px_0_rgba(0,0,0,0.15)]",
              @class
            ]}
            {@rest}
          >
            <div class="flex gap-2 items-center text-amber-900">
              <span class="text-lg [text-shadow:0_-1px_0_rgba(0,0,0,0.3),0_1px_0_rgba(255,255,255,0.2)]">
                {@text}
              </span>
              {render_slot(@inner_block)}
            </div>
          </.link>
        </div>
      </div>
      """
    else
      ~H"""
      <div class="w-fit perspective-500 translate-y-[2px]">
        <div class="bg-gray-800 border-x-3 border-t-0 border-b-3 border-gray-800 rounded-sm rotate-x-[30deg] origin-top">
          <button
            class={[
              "h-8 rounded-sm [box-shadow:inset_0_2px_0_rgba(255,255,255,0.35),inset_0_-2px_0_rgba(0,0,0,0.15),0_4px_0_rgba(151,60,0)] border-none bg-amber-500 -translate-y-1 active:-translate-y-0 active:[box-shadow:inset_0_2px_0_rgba(255,255,255,0.35),inset_0_-2px_0_rgba(0,0,0,0.15)]",
              @class
            ]}
            {@rest}
          >
            <div class="flex gap-2 items-center text-amber-900">
              <span class="text-lg [text-shadow:0_-1px_0_rgba(0,0,0,0.3),0_1px_0_rgba(255,255,255,0.2)]">
                {@text}
              </span>
              {render_slot(@inner_block)}
            </div>
          </button>
        </div>
      </div>
      """
    end
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from the `deps/heroicons` directory and bundled within
  your compiled app.css by the plugin in `assets/vendor/heroicons.js`.

  ## Examples

      <.icon name="hero-x-mark" />
      <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :any, default: "size-4"

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  # -- Card components  --

  @doc """
  Renders a single playing card. `card` is an `Isaludic.Card` (or any map with
  `:value`, `:suit` and `:is_joker`). `hide_value` shows the card back instead.
  When `click` is given, the card emits a `click_card` event with `source`,
  `idx`, `stack` and `player` as `phx-value-*`.
  """
  attr :card, :any, required: true
  attr :under, :boolean, default: false
  attr :selected, :boolean, default: false
  attr :click, :map, default: nil
  attr :hide_value, :boolean, default: false
  attr :class, :any, default: ""

  def card(assigns) do
    assigns =
      assigns
      |> assign(:color_class, card_color_class(assigns.card, assigns.hide_value))
      |> assign(
        :num_pos_class,
        if(assigns.under,
          do: "text-[12px] font-bold",
          else: "text-2xl font-bold items-center justify-center"
        )
      )

    ~H"""
    <div>
      <%= if @hide_value do %>
        <div
          class={[
            @color_class,
            "w-16 h-20 rounded-md flex select-none",
            @selected && not @under && "!outline-3 !outline-slate-700",
            @class
          ]}
          phx-click={@click[:event]}
          phx-value-index={@click[:index]}
          phx-value-pos={@click[:pos]}
          phx-value-row={@click[:row]}
          phx-value-col={@click[:col]}
        >
          <span class={[
            "flex -rotate-10 items-center justify-center w-full text-white font-bold",
            @under && "ml-1 gap-0.5"
          ]}>
            Ludic
          </span>
        </div>
      <% else %>
        <div
          class={[
            @color_class,
            "w-16 h-20 rounded-md flex select-none",
            @num_pos_class,
            @selected && not @under && "!outline-3 !outline-slate-700",
            @class
          ]}
          phx-click={@click[:event]}
          phx-value-index={@click[:index]}
          phx-value-pos={@click[:pos]}
          phx-value-row={@click[:row]}
          phx-value-col={@click[:col]}
        >
          <span class={[
            "flex",
            @under && "ml-1 gap-0.5",
            !@under && "flex-col items-center leading-none"
          ]}>
            <span>{rank_label(@card)}</span>
            <span>{suit_symbol(@card.suit)}</span>
          </span>
        </div>
      <% end %>
    </div>
    """
  end

  defp card_color_class(_card, true), do: "bg-cyan-600 border border-cyan-800"

  defp card_color_class(%{is_joker: true}, _),
    do: "bg-purple-100 border-2 border-purple-400 text-purple-700"

  defp card_color_class(%{suit: suit}, _) when suit in [:heart, :diamond],
    do: "bg-white border-2 border-slate-300 text-red-600"

  defp card_color_class(_card, _), do: "bg-white border-2 border-slate-300 text-slate-900"

  defp rank_label(%{is_joker: true, value: value}) when value in [nil, 0], do: "0"
  defp rank_label(%{face: :jack}), do: "J"
  defp rank_label(%{face: :queen}), do: "Q"
  defp rank_label(%{face: :king}), do: "K"
  defp rank_label(%{face: :ace}), do: "A"
  defp rank_label(%{face: nil, value: value}), do: to_string(value)

  defp suit_symbol(:spade), do: "♠"
  defp suit_symbol(:club), do: "♣"
  defp suit_symbol(:diamond), do: "♦"
  defp suit_symbol(:heart), do: "♥"
  defp suit_symbol(_), do: "★"

  @doc "An empty, dashed placeholder where a card can go."
  attr :class, :any, default: ""
  slot :inner_block, required: false

  def card_slot(assigns) do
    ~H"""
    <div class={[
      "w-16 h-20 rounded-md border border-dashed flex items-center justify-center",
      @class
    ]}>
      <span>{render_slot(@inner_block)}</span>
    </div>
    """
  end

  @doc """
  A pile showing only its top card, with the next card peeking out underneath.
  `cards` is ordered top-first. With `facedown`, no card values are shown.
  """
  attr :cards, :list, required: true
  attr :click, :map, default: nil
  attr :large, :boolean, default: false
  attr :facedown, :boolean, default: false
  attr :class, :string, default: ""

  def stack(%{large: true} = assigns) do
    assigns = assign(assigns, :has_under, length(assigns.cards) > 1)

    ~H"""
    <div class={["relative h-20 w-16", @class]}>
      <%= if @cards == [] do %>
        <.card_slot class="h-20 w-16" click={@click} />
      <% else %>
        <div :if={@has_under} class="absolute rotate-5">
          <.card
            card={Enum.at(@cards, 1)}
            hide_value={@facedown}
            class="!bg-slate-700 !border-slate-700 !text-white h-24 w-18"
          />
        </div>
        <div class="relative z-1">
          <.card card={hd(@cards)} hide_value={@facedown} click={@click} class="h-24 w-18" />
        </div>
      <% end %>
    </div>
    """
  end

  def stack(assigns) do
    assigns = assign(assigns, :has_under, length(assigns.cards) > 1)

    ~H"""
    <div class={["relative h-20 w-16", @class]}>
      <%= if @cards == [] do %>
        <.card_slot click={@click} />
      <% else %>
        <div :if={@has_under} class="absolute rotate-5">
          <.card
            card={Enum.at(@cards, 1)}
            hide_value={@facedown}
            class="!bg-slate-700 !border-slate-700 !text-white"
          />
        </div>
        <div class="relative z-1">
          <.card card={hd(@cards)} hide_value={@facedown} click={@click} />
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  A pile of overlapping cards that can expand to show every card.
  `cards` is ordered top-first; `click` must be a map (it is given `:idx` per card).
  """
  attr :cards, :list, required: true
  attr :expanded, :boolean, default: false
  attr :selected_card, :any, default: nil
  attr :click, :map, required: true

  def discard_stack(assigns) do
    assigns =
      assign(
        assigns,
        under_rot: if(length(assigns.cards) > 1, do: "rotate-5", else: ""),
        over_rot: if(length(assigns.cards) > 1, do: "-rotate-5", else: "")
      )

    ~H"""
    <div class="relative h-16 w-12 cursor-pointer">
      <.card_slot :if={@cards == []} click={@click} />
      <%= for {card, idx} <- Enum.with_index(Enum.reverse(@cards)) do %>
        <% under_card = not @expanded and idx < length(@cards) - 1 %>
        <div
          class={[
            "absolute w-full transition-all duration-100 ease-in-out",
            if(under_card, do: "p-[1px] rounded-md #{@under_rot}")
          ]}
          style={"top: #{if @expanded, do: idx * 16, else: 0}px; z-index: #{idx}; #{if under_card, do: "background-color: black"}"}
        >
          <.card
            card={card}
            under={idx < length(@cards) - 1}
            selected={@selected_card == {"discard", @click[:stack]} and idx == length(@cards) - 1}
            class={under_card && "!bg-slate-700 !border-slate-700 !text-white"}
            click={@click && Map.put(@click, :idx, idx)}
          />
        </div>
      <% end %>
    </div>
    """
  end
end
