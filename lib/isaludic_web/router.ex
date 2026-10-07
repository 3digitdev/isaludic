defmodule IsaludicWeb.Router do
  use IsaludicWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {IsaludicWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", IsaludicWeb do
    pipe_through :browser

    live "/", GameLive
    live "/dead-center", Games.DeadCenterLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", IsaludicWeb do
  #   pipe_through :api
  # end
end
