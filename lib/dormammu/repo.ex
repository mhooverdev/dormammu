defmodule Dormammu.Repo do
  use Ecto.Repo,
    otp_app: :dormammu,
    adapter: Ecto.Adapters.Postgres
end
