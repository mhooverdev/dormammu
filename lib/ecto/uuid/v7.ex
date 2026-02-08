defmodule Ecto.UUID.V7 do
  @moduledoc """
  UUIDv7 Ecto type.

  - Stored in Postgres as `uuid`
  - Autogenerates UUIDv7 (time-ordered) strings

  This lets you use:

      @primary_key {:id, Ecto.UUID.V7, autogenerate: true}
      @foreign_key_type Ecto.UUID.V7

  See RFC 9562 UUID version 7.
  """

  @behaviour Ecto.Type
  import Bitwise

  @type t :: String.t()

  @impl true
  def type, do: :uuid

  @impl true
  def cast(value), do: Ecto.UUID.cast(value)

  @impl true
  def load(value), do: Ecto.UUID.load(value)

  @impl true
  def dump(value), do: Ecto.UUID.dump(value)

  @impl true
  def embed_as(_format), do: :self

  @impl true
  def equal?(a, b), do: a == b

  @impl true
  def autogenerate, do: generate()

  @doc """
  Generates a UUIDv7 string.
  """
  @spec generate() :: t()
  def generate do
    ts_ms = System.system_time(:millisecond) &&& (1 <<< 48) - 1

    # 74 random bits split into rand_a (12) and rand_b (62)
    <<rand_a::12, rand_b::62, _discard::6>> = :crypto.strong_rand_bytes(10)

    # Variant is 0b10 (RFC4122)
    uuid_bin = <<ts_ms::48, 7::4, rand_a::12, 2::2, rand_b::62>>

    encode(uuid_bin)
  end

  defp encode(
         <<a::binary-size(4), b::binary-size(2), c::binary-size(2), d::binary-size(2),
           e::binary-size(6)>>
       ) do
    Base.encode16(a, case: :lower) <>
      "-" <>
      Base.encode16(b, case: :lower) <>
      "-" <>
      Base.encode16(c, case: :lower) <>
      "-" <>
      Base.encode16(d, case: :lower) <>
      "-" <>
      Base.encode16(e, case: :lower)
  end
end
