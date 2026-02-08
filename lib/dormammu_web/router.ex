defmodule DormammuWeb.Router do
  use DormammuWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {DormammuWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug DormammuWeb.Plugs.AssignCurrentUser
  end

  pipeline :require_user do
    plug DormammuWeb.Plugs.RequireUser
  end

  pipeline :require_admin do
    plug DormammuWeb.Plugs.RequireAdmin
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Root redirects to login if no session, otherwise role-based redirect
  scope "/", DormammuWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/login", SessionController, :new
    post "/login", SessionController, :create
    delete "/logout", SessionController, :delete
  end

  scope "/", DormammuWeb do
    pipe_through :browser

    live_session :user,
      on_mount: [
        {DormammuWeb.UserAuth, :mount_current_user},
        {DormammuWeb.UserAuth, :ensure_user}
      ] do
      live "/me/records", RecordsLive
      live "/me/dashboard", DashboardLive
    end

    pipe_through :require_user
    get "/me/records/export.csv", RecordsExportController, :export
  end

  scope "/admin", DormammuWeb do
    pipe_through :browser

    live_session :admin,
      on_mount: [
        {DormammuWeb.UserAuth, :mount_current_user},
        {DormammuWeb.UserAuth, :ensure_admin}
      ] do
      live "/", AdminDashboardLive
      live "/users", AdminUsersLive
      live "/reports", AdminReportsLive
    end
  end

  scope "/admin", DormammuWeb do
    pipe_through [:browser, :require_admin]

    get "/reports/export.csv", AdminReportsExportController, :export
  end

  # Other scopes may use custom stacks.
  # scope "/api", DormammuWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:dormammu, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: DormammuWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
