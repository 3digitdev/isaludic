defmodule IsaludicWeb.GameLiveTest do
  use IsaludicWeb.ConnCase

  import Phoenix.LiveViewTest

  test "the info icon is a button that opens that game's modal, which has a close button" do
    {:ok, view, html} = live(build_conn(), "/")

    assert has_element?(view, ~s(button[aria-label="About Dead Center"] .hero-information-circle))
    assert has_element?(view, ~s(#dead-center-info[role="dialog"]))
    assert html =~ "Dead Center"
    assert html =~ "Complexity: 3"

    # opening and closing are JS commands, run in the browser
    assert has_element?(
             view,
             ~s(button[aria-label="About Dead Center"][phx-click*="dead-center-info"])
           )

    assert has_element?(view, ~s(#dead-center-info button[aria-label="Close"]))
  end
end
