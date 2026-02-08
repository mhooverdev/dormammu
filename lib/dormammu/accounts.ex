defmodule Dormammu.Accounts do
  @moduledoc """
  Accounts context for users and authentication.
  """
  import Ecto.Query, warn: false
  alias Dormammu.Repo
  alias Dormammu.Accounts.User
  alias Pbkdf2

  # -- Queries
  def list_users do
    User |> order_by([u], asc: u.inserted_at) |> Repo.all()
  end

  def get_user(id), do: Repo.get(User, id)
  def get_user!(id), do: Repo.get!(User, id)
  def get_user_by_email(email) when is_binary(email), do: Repo.get_by(User, email: email)

  def get_user_by_os(os_username) when is_binary(os_username),
    do: Repo.get_by(User, os_username: os_username)

  def get_user_by_os(_), do: nil

  # -- Provisioning / helpers
  def ensure_os_user(os_username, display_name \\ nil)
  def ensure_os_user(nil, _), do: {:error, :no_os_user}

  def ensure_os_user(os_username, display_name) do
    case get_user_by_os(os_username) do
      nil ->
        %User{}
        |> User.os_user_changeset(%{
          os_username: os_username,
          display_name: display_name || os_username
        })
        |> Repo.insert()

      user ->
        {:ok, user}
    end
  end

  # -- User creation
  def create_user(attrs) do
    %User{}
    |> User.user_changeset(Map.put(attrs, :role, :user))
    |> Repo.insert()
  end

  def create_admin(attrs) do
    %User{}
    |> User.admin_changeset(Map.put(attrs, :role, :admin))
    |> Repo.insert()
  end

  def update_user(%User{} = user, attrs) do
    user
    |> User.profile_changeset(attrs)
    |> Repo.update()
  end

  def deactivate_user(%User{} = user) do
    update_user(user, %{active: false})
  end

  # -- Auth (single login for all users; role determines access after login)
  def authenticate_user(email, password) when is_binary(email) and is_binary(password) do
    authenticate_user_with_role(email, password, nil)
  end

  def authenticate_admin(email, password) when is_binary(email) and is_binary(password) do
    authenticate_user_with_role(email, password, :admin)
  end

  defp authenticate_user_with_role(email, password, required_role) do
    with %User{active: true} = user <- get_user_by_email(email),
         true <- user.password_hash && Pbkdf2.verify_pass(password, user.password_hash),
         true <- required_role == nil or user.role == required_role do
      {:ok, user}
    else
      _ -> {:error, :unauthorized}
    end
  end

  # -- Changesets exposure
  def change_user(%User{} = user, attrs \\ %{}) do
    User.profile_changeset(user, attrs)
  end
end
