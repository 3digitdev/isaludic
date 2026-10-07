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

  defp card_html(card), do: render_component(&card/1, card: card)
end
