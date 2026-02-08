defmodule Dormammu.Schema do
  @moduledoc """
  Base schema for Dormammu.

  Uses UUIDv7 as the primary/foreign key type.
  """

  defmacro __using__(_) do
    quote do
      use Ecto.Schema
      import Ecto.Changeset

      @primary_key {:id, Ecto.UUID.V7, autogenerate: true}
      @foreign_key_type Ecto.UUID.V7

      @timestamps_opts [type: :utc_datetime]
    end
  end
end
