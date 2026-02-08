alias Dormammu.{Accounts, Repo, Tracking}

# Ensure users table exists (run pending migrations if any)
case Ecto.Migrator.run(Repo, :up, all: true) do
  [] -> :ok
  versions -> IO.puts("Ran #{length(versions)} migration(s): #{inspect(versions)}")
end

# --- Test regular user (email/password login) ---
test_user_email = "testuser@example.com"
test_user_password = "testuser123"

unless Accounts.get_user_by_email(test_user_email) do
  {:ok, _} =
    Accounts.create_user(%{
      os_username: "testuser",
      email: test_user_email,
      password: test_user_password,
      display_name: "Test User"
    })

  IO.puts("Seeded test user: #{test_user_email} (password: #{test_user_password})")
else
  IO.puts("Test user already exists (#{test_user_email})")
end

# --- Test admin (email/password login) ---
test_admin_email = "testadmin@example.com"
test_admin_password = "testadmin123"

unless Accounts.get_user_by_email(test_admin_email) do
  {:ok, _} =
    Accounts.create_admin(%{
      os_username: "testadmin",
      email: test_admin_email,
      password: test_admin_password,
      display_name: "Test Admin"
    })

  IO.puts("Seeded test admin: #{test_admin_email} (password: #{test_admin_password})")
else
  IO.puts("Test admin already exists (#{test_admin_email})")
end

# --- Default admin (env overrides or fallbacks) ---
admin_email = System.get_env("DORMAMMU_ADMIN_EMAIL") || "admin@example.com"
admin_password = System.get_env("DORMAMMU_ADMIN_PASSWORD") || "changeme123"

unless Accounts.get_user_by_email(admin_email) do
  {:ok, _} =
    Accounts.create_admin(%{
      os_username: "admin",
      email: admin_email,
      password: admin_password,
      display_name: "Admin"
    })

  IO.puts("Seeded admin: #{admin_email} (password: #{admin_password})")
else
  IO.puts("Admin already exists (#{admin_email})")
end

# Seed tasks for current OS user
os_user = System.get_env("USERNAME") || System.get_env("USER")

if is_binary(os_user) do
  case Accounts.ensure_os_user(os_user, os_user) do
    {:ok, user} ->
      for name <- ["Focus Work", "Meetings", "Break"] do
        Tracking.create_task_type(user, %{name: name})
      end

    _ ->
      :ok
  end
end

# Seed tasks for testuser
case Accounts.ensure_os_user("testuser", "Test User") do
  {:ok, user} ->
    for name <- ["Debug", "Research", "Admin"] do
      Tracking.create_task_type(user, %{name: name})
    end

  _ ->
    :ok
end
