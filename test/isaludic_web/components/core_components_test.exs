defmodule IsaludicWeb.CoreComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest
  import IsaludicWeb.CoreComponents

  alias Isaludic.Card

  @ace %Card{value: 1, suit: :heart, face: :ace, is_joker: false}
  @seven %Card{value: 7, suit: :spade, face: nil, is_joker: false}
  @joker %Card{value: 0, suit: nil, face: nil, is_joker: true}

  test "card renders rank and suit" do
    html = card_html(@ace)
    assert html =~ "A"
    assert html =~ "♥"
    assert html =~ "text-red-600"
  end

  test "joker and hidden card" do
    assert card_html(@joker) =~ "★"
    refute render_component(&card/1, card: @seven, hide_value: true) =~ "♠"
  end

  test "stack and discard_stack render all card kinds" do
    cards = [@ace, @seven, @joker]
    assert render_component(&stack/1, cards: cards) =~ "♥"
    assert render_component(&discard_stack/1, cards: cards, click: %{stack: 0}) =~ "♠"
  end

  test "facedown stack hides every value" do
    html = render_component(&stack/1, cards: [@ace, @seven, @joker], facedown: true)
    refute html =~ "♥"
    refute html =~ "♠"
    refute html =~ "★"
  end

  test "modal renders its title and content, with an X that hides it" do
    html =
      render_component(&modal/1,
        id: "rules",
        title: "Rules",
        inner_block: [%{__slot__: :inner_block, inner_block: fn _, _ -> "Don't let them in." end}]
      )

    assert html =~ ~s(id="rules")
    assert html =~ "Rules"
    assert html =~ "Don&#39;t let them in." or html =~ "Don't let them in."
    assert html =~ ~s(aria-label="Close")
    assert html =~ "hide"
    assert html =~ "#rules"
  end

  test "modal also closes on a click outside the panel and on Escape" do
    html =
      render_component(&modal/1,
        id: "rules",
        title: "Rules",
        inner_block: [%{__slot__: :inner_block, inner_block: fn _, _ -> "body" end}]
      )

    doc = LazyHTML.from_fragment(html)
    backdrop = LazyHTML.query(doc, "#rules > div.absolute")
    assert [click] = LazyHTML.attribute(backdrop, "phx-click")
    assert click =~ "#rules"

    root = LazyHTML.query(doc, "#rules")
    assert LazyHTML.attribute(root, "phx-key") == ["Escape"]
    assert [keydown] = LazyHTML.attribute(root, "phx-window-keydown")
    assert keydown =~ "#rules"

    # the panel is capped at 90dvh and only its content scrolls
    assert LazyHTML.query(doc, "#rules > div.max-h-\\[90dvh\\]") |> Enum.count() == 1
    assert LazyHTML.query(doc, "#rules div.overflow-y-auto") |> Enum.count() == 1

    # the panel (where the content lives) is not inside the backdrop
    assert LazyHTML.query(backdrop, "h2") |> Enum.count() == 0
  end

  defp card_html(card), do: render_component(&card/1, card: card)
end
