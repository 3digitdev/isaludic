defmodule Isaludic.CardTest do
  use ExUnit.Case, async: true

  alias Isaludic.Card

  defp c(value, suit), do: %Card{value: value, suit: suit, face: nil, is_joker: false}

  # House is [col][row]; the cell at {row, col} holds value row + 3 * col + 2 (all spades).
  defp house, do: for(col <- 0..2, do: for(row <- 0..2, do: c(row + 3 * col + 2, :spade)))
end
