defmodule Dormammu.Accounts.User do
  @moduledoc """
  User schema.

  Regular users are auto-provisioned from the OS username.
  Admin users authenticate via email/password.
  """
  use Dormammu.Schema
  alias Pbkdf2

  @roles [:user, :admin]

  schema "users" do
    field :os_username, :string
    field :display_name, :string
    field :role, Ecto.Enum, values: @roles, default: :user
    field :email, :string
    field :password, :string, virtual: true
    field :password_hash, :string
    field :active, :boolean, default: true

    timestamps()
  end

  @doc """
  Changeset for auto-provisioned OS users.
  """
  def os_user_changeset(user, attrs) do
    user
    |> cast(attrs, [:os_username, :display_name])
    |> validate_required([:os_username])
    |> unique_constraint(:os_username)
  end

  @doc """
  Changeset for regular user creation (email/password).
  """
  def user_changeset(user, attrs) do
    user
    |> cast(attrs, [:os_username, :email, :display_name, :password, :role])
    |> validate_required([:email, :password])
    |> validate_inclusion(:role, @roles)
    |> validate_length(:password, min: 8)
    |> unique_constraint(:email)
    |> put_password_hash()
  end

  @doc """
  Changeset for admin creation/update.
  """
  def admin_changeset(user, attrs) do
    user
    |> cast(attrs, [:os_username, :email, :display_name, :password, :role, :active])
    |> validate_required([:os_username, :email, :password, :role])
    |> validate_inclusion(:role, @roles)
    |> validate_length(:password, min: 8)
    |> unique_constraint(:email)
    |> put_password_hash()
  end

  @doc """
  Changeset for updating user profile (non-admin passwordless).
  """
  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, [:display_name, :active])
  end

  defp put_password_hash(changeset) do
    if password = get_change(changeset, :password) do
      change(changeset, password_hash: Pbkdf2.hash_pwd_salt(password))
    else
      changeset
    end
  end
end
