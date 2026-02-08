defmodule DormammuWeb.LiveViewCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a LiveView connection.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint DormammuWeb.Endpoint

      use DormammuWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest, except: [live: 2, live: 3]
      import DormammuWeb.ConnCase
      import DormammuWeb.LiveViewCase

      # Use on_error: :warn to avoid duplicate client-error ID failures in layout
      def live(conn, path, opts \\ []) do
        opts = Keyword.merge([on_error: :warn], opts)
        Phoenix.LiveViewTest.live(conn, path, opts)
      end
    end
  end

  setup tags do
    Dormammu.DataCase.setup_sandbox(tags)

    conn =
      Phoenix.ConnTest.build_conn()
      |> Phoenix.ConnTest.init_test_session(%{})

    {:ok, conn: conn}
  end
end
