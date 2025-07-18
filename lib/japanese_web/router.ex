defmodule JapaneseWeb.Router do
  use JapaneseWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {JapaneseWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", JapaneseWeb do
    pipe_through :browser

    get "/", RootController, :home

    live "/stories", StoryLive.Index, :index
    live "/stories/new", StoryLive.Index, :new

    live "/stories/:name", StoryLive.Show, :show
    live "/stories/:name/add", StoryLive.Show, :add
    live "/stories/:name/edit", StoryLive.Show, :edit
    live "/stories/:name/:page", PageLive.Show, :show
    get "/stories/:name/:page/japanese", PageController, :japanese
  end

  # Other scopes may use custom stacks.
  # scope "/api", JapaneseWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:japanese, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: JapaneseWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
