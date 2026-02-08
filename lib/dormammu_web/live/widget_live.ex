defmodule DormammuWeb.WidgetLive do
  @moduledoc """
  Compact LiveView widget for rotating tasks and tracking time.
  """
  use DormammuWeb, :live_view

  alias Dormammu.Tracking
  alias Dormammu.Accounts.User

  @tick_ms 1000

  @impl true
  def mount(_params, session, socket) do
    user = get_user_from_session(session)

    case user do
      %User{} = user ->
        tasks = Tracking.list_task_types(user)
        active_entry = Tracking.current_entry(user)

        socket =
          socket
          |> assign(:user, user)
          |> assign(:tasks, tasks)
          |> assign(:active_entry, active_entry)
          |> assign(:mode, mode_from(active_entry))
          |> assign(:minimized, false)
          |> assign(:elapsed, elapsed_seconds(active_entry))
          |> assign(:sort_mode, :custom)
          |> assign(:editing_task_id, nil)
          |> assign(:edit_name, "")
          |> maybe_schedule_tick()

        {:ok, socket}

      _ ->
        {:ok, assign(socket, :user, nil)}
    end
  end

  defp get_user_from_session(session) do
    case session["session_user_id"] do
      nil -> nil
      id -> Dormammu.Accounts.get_user(id)
    end
  end

  @impl true
  def handle_event("play_task", params, %{assigns: %{user: user, tasks: tasks}} = socket) do
    raw = params["task_id"] || ""
    task_id = if is_binary(raw), do: raw, else: to_string(raw)

    case task_id do
      "" ->
        {:noreply, socket}

      _ ->
        task = find_task(tasks, task_id)

        socket =
          case task && Tracking.land_on_task(user, task) do
            {:ok, entry} ->
              socket
              |> assign(:active_entry, entry)
              |> assign(:mode, :running)
              |> assign(:elapsed, elapsed_seconds(entry))
              |> maybe_schedule_tick()

            _ ->
              put_flash(socket, :error, "Failed to start task")
          end

        {:noreply, socket}
    end
  end

  def handle_event(
        "reorder_tasks",
        %{"order" => order_str},
        %{assigns: %{user: user}} = socket
      ) do
    reordered_ids =
      order_str
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.filter(&(&1 != ""))

    case Tracking.update_task_positions(user, reordered_ids) do
      {:ok, _} ->
        tasks = Tracking.list_task_types(user)
        {:noreply, assign(socket, tasks: tasks, sort_mode: :custom)}

      _ ->
        {:noreply, put_flash(socket, :error, "Failed to reorder")}
    end
  end

  def handle_event("toggle_sort", _params, %{assigns: %{user: user, tasks: tasks, sort_mode: current_mode}} = socket) do
    new_mode = case current_mode do
      :asc -> :desc
      _ -> :asc
    end

    sorted_tasks = case new_mode do
      :asc -> Enum.sort_by(tasks, & String.downcase(&1.name))
      :desc -> Enum.sort_by(tasks, & String.downcase(&1.name), :desc)
    end

    sorted_ids = Enum.map(sorted_tasks, & &1.id)

    case Tracking.update_task_positions(user, sorted_ids) do
      {:ok, _} ->
        tasks = Tracking.list_task_types(user)
        {:noreply, assign(socket, tasks: tasks, sort_mode: new_mode)}

      _ ->
        {:noreply, put_flash(socket, :error, "Failed to sort")}
    end
  end

  def handle_event("sort_custom", _params, %{assigns: %{user: user}} = socket) do
    tasks = Tracking.list_task_types(user)
    {:noreply, assign(socket, tasks: tasks, sort_mode: :custom)}
  end

  def handle_event("start_edit", %{"task_id" => task_id, "name" => name}, socket) do
    {:noreply, assign(socket, editing_task_id: task_id, edit_name: name)}
  end

  def handle_event("cancel_edit", _params, socket) do
    {:noreply, assign(socket, editing_task_id: nil, edit_name: "")}
  end

  def handle_event("save_edit", %{"name" => new_name}, %{assigns: %{user: user, editing_task_id: task_id, tasks: tasks}} = socket) do
    new_name = String.trim(new_name || "")

    socket =
      case new_name do
        "" ->
          put_flash(socket, :error, "Task name cannot be blank")

        _ ->
          task = find_task(tasks, task_id)

          case task && Tracking.update_task_type(task, %{name: new_name}) do
            {:ok, _} ->
              tasks = Tracking.list_task_types(user)
              socket
              |> assign(:tasks, tasks)
              |> assign(:editing_task_id, nil)
              |> assign(:edit_name, "")

            {:error, changeset} ->
              put_flash(socket, :error, "Failed to update: #{humanize_errors(changeset)}")

            _ ->
              put_flash(socket, :error, "Task not found")
          end
      end

    {:noreply, socket}
  end

  def handle_event("delete_task", %{"task_id" => task_id}, %{assigns: %{user: user, tasks: tasks}} = socket) do
    task = find_task(tasks, task_id)

    socket =
      case task && Tracking.soft_delete_task_type(task) do
        {:ok, _} ->
          tasks = Tracking.list_task_types(user)
          assign(socket, :tasks, tasks)

        {:error, _} ->
          put_flash(socket, :error, "Failed to delete task")

        _ ->
          put_flash(socket, :error, "Task not found")
      end

    {:noreply, socket}
  end

  def handle_event("toggle_minimize", _params, socket) do
    {:noreply, assign(socket, :minimized, !socket.assigns.minimized)}
  end

  def handle_event("create_task", %{"name" => name}, %{assigns: %{user: user}} = socket) do
    name = String.trim(name || "")

    socket =
      case name do
        "" ->
          put_flash(socket, :error, "Task name cannot be blank")

        _ ->
          case Tracking.create_task_type(user, %{name: name}) do
            {:ok, task} ->
              tasks = socket.assigns.tasks ++ [task]

              socket =
                socket
                |> assign(:tasks, tasks)

              case Tracking.land_on_task(user, task) do
                {:ok, entry} ->
                  socket
                  |> assign(:active_entry, entry)
                  |> assign(:mode, :running)
                  |> assign(:elapsed, elapsed_seconds(entry))
                  |> maybe_schedule_tick()

                _ ->
                  socket
              end

            {:error, changeset} ->
              put_flash(socket, :error, "Could not create task: #{humanize_errors(changeset)}")
          end
      end

    {:noreply, socket}
  end

  def handle_event("stop", _params, %{assigns: %{user: user}} = socket) do
    case Tracking.stop_active_entry(user) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:active_entry, nil)
         |> assign(:mode, :stopped)
         |> assign(:elapsed, 0)}

      {:error, _} = err ->
        {:noreply, put_flash(socket, :error, "Failed to stop: #{inspect(err)}")}
    end
  end

  @impl true
  def handle_info(:tick, socket) do
    socket =
      socket
      |> update(:elapsed, fn _ -> elapsed_seconds(socket.assigns.active_entry) end)
      |> maybe_schedule_tick()

    {:noreply, socket}
  end

  # -- Helpers

  defp find_task(tasks, id), do: Enum.find(tasks, &(to_string(&1.id) == to_string(id)))

  defp mode_from(nil), do: :stopped
  defp mode_from(_), do: :running

  defp elapsed_seconds(nil), do: 0

  defp elapsed_seconds(entry) do
    now = DateTime.utc_now()

    case entry do
      %{started_at: %DateTime{} = started, ended_at: nil} ->
        DateTime.diff(now, started, :second)

      %{duration_seconds: secs} when is_integer(secs) ->
        secs

      _ ->
        0
    end
  end

  defp maybe_schedule_tick(socket) do
    if connected?(socket) do
      Process.send_after(self(), :tick, @tick_ms)
    end

    socket
  end

  defp humanize_errors(changeset) do
    errors =
      changeset
      |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
        Enum.reduce(opts, msg, fn {key, value}, acc ->
          String.replace(acc, "%{#{key}}", to_string(value))
        end)
      end)

    errors
    |> Enum.map(fn {k, v} -> "#{Phoenix.Naming.humanize(to_string(k))} #{Enum.join(v, ", ")}" end)
    |> Enum.join("; ")
  end

  # -- Render
  @impl true
  def render(%{user: nil} = assigns), do: ~H""

  def render(assigns) do
    ~H"""
    <div
      id="widget-inner"
      class={[
        "fixed bottom-4 right-4 z-40 flex flex-col gap-2",
        @minimized && "opacity-90"
      ]}
    >
      <div
        class={[
          "shadow-lg rounded-2xl border-4 bg-base-100 text-base-content transition-all w-96 max-h-[80vh] flex flex-col",
          border_for(@mode),
          @minimized && "h-12 w-12 flex items-center justify-center cursor-pointer"
        ]}
        phx-click={@minimized && JS.push("toggle_minimize", target: "#widget")}
        phx-target="#widget"
      >
        <%= if @minimized do %>
          <div class="text-sm font-semibold">⏱️</div>
        <% else %>
          <div class="flex items-center justify-between p-3 border-b border-base-300">
            <div class="text-sm font-semibold">Time Tracker</div>
            <div class="flex items-center gap-2">
              <button class="btn btn-xs btn-ghost" phx-click="toggle_minimize" phx-target="#widget">
                —
              </button>
              <a class="btn btn-xs btn-ghost" href={~p"/me/dashboard"}>⚙️</a>
              <button
                type="button"
                class="btn btn-xs btn-ghost"
                phx-click={JS.add_class("hidden", to: "#widget-overlay")}
                aria-label="Close widget"
              >
                <.icon name="hero-x-mark" class="w-4 h-4" />
              </button>
            </div>
          </div>

          <div class="p-4 space-y-3 flex flex-col flex-1 overflow-hidden">
            <div class="flex items-center justify-between">
              <div class="text-xs opacity-70 capitalize">{@mode}</div>
              <%= if @tasks != [] do %>
                <div class="flex gap-1">
                  <button
                    type="button"
                    class={[
                      "btn btn-xs",
                      @sort_mode == :custom && "btn-ghost" || "btn-primary"
                    ]}
                    phx-click="toggle_sort"
                    phx-target="#widget"
                    title="Toggle alphabetical sort"
                  >
                    <%= case @sort_mode do %>
                      <% :asc -> %>
                        A-Z ↓
                      <% :desc -> %>
                        Z-A ↑
                      <% _ -> %>
                        A-Z
                    <% end %>
                  </button>
                  <button
                    type="button"
                    class={[
                      "btn btn-xs",
                      @sort_mode == :custom && "btn-primary" || "btn-ghost"
                    ]}
                    phx-click="sort_custom"
                    phx-target="#widget"
                    title="Use custom drag-and-drop order"
                  >
                    Custom
                  </button>
                </div>
              <% end %>
            </div>
            <div class="flex-1 overflow-y-auto space-y-1 min-h-0">
              <%= if @tasks == [] do %>
                <p class="text-sm opacity-70">No tasks yet. Create one below.</p>
              <% else %>
                <.all_tasks_draggable
                  tasks={@tasks}
                  active_entry={@active_entry}
                  on_play="play_task"
                  on_stop="stop"
                  on_reorder="reorder_tasks"
                  editing_task_id={@editing_task_id}
                  edit_name={@edit_name}
                />
              <% end %>
            </div>

            <div class="text-center text-3xl font-mono">
              {format_elapsed(@elapsed)}
            </div>

            <div class="flex justify-end text-xs">
              <button
                id="widget-stop-btn"
                class="btn btn-xs btn-error"
                phx-click="stop"
                phx-target="#widget"
              >
                Stop
              </button>
            </div>

            <form id="task-form" class="flex gap-2" phx-submit="create_task" phx-target="#widget">
              <input
                type="text"
                name="name"
                placeholder="New task name"
                class="input input-bordered input-sm flex-1"
              />
              <button class="btn btn-primary btn-sm" type="submit">+</button>
            </form>
          </div>
        <% end %>
      </div>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".TaskListSortable">
      export default {
        mounted() {
          this.setupDragDrop()
        },
        updated() {
          this.setupDragDrop()
        },
        setupDragDrop() {
          const container = this.el
          const eventName = container.dataset.reorderEvent
          const slots = container.querySelectorAll(".task-slot")
          
          slots.forEach((slot) => {
            // Remove existing listeners by cloning (prevents duplicates)
            const newSlot = slot.cloneNode(true)
            slot.parentNode.replaceChild(newSlot, slot)
            
            newSlot.ondragstart = (e) => {
              if (e.target.closest("[data-no-drag]")) {
                e.preventDefault()
                return
              }
              e.dataTransfer.effectAllowed = "move"
              e.dataTransfer.setData("text/plain", newSlot.dataset.taskId)
              newSlot.classList.add("opacity-50")
            }
            
            newSlot.ondragend = () => {
              newSlot.classList.remove("opacity-50")
            }
            
            newSlot.ondragover = (e) => {
              e.preventDefault()
              e.dataTransfer.dropEffect = "move"
              newSlot.classList.add("border-primary")
            }
            
            newSlot.ondragleave = () => {
              newSlot.classList.remove("border-primary")
            }
            
            newSlot.ondrop = (e) => {
              e.preventDefault()
              newSlot.classList.remove("border-primary")
              const draggedId = e.dataTransfer.getData("text/plain")
              if (!draggedId) return
              const selector = "[data-task-id=\"" + draggedId + "\"]"
              const dragged = container.querySelector(selector)
              if (!dragged || dragged === newSlot) return
              
              // Insert before or after based on mouse position
              const rect = newSlot.getBoundingClientRect()
              const midpoint = rect.top + rect.height / 2
              if (e.clientY < midpoint) {
                container.insertBefore(dragged, newSlot)
              } else {
                container.insertBefore(dragged, newSlot.nextSibling)
              }
              
              const order = Array.from(container.querySelectorAll(".task-slot"))
                .map((s) => s.dataset.taskId)
                .filter(Boolean)
              this.pushEvent(eventName, { order: order.join(",") })
            }
          })
        }
      }
    </script>
    """
  end

  defp border_for(:selection), do: "border-amber-400"
  defp border_for(:running), do: "border-green-500"
  defp border_for(:stopped), do: "border-red-500"
  defp border_for(_), do: "border-base-300"

  attr :tasks, :list, required: true
  attr :active_entry, :map, default: nil
  attr :on_play, :string, required: true
  attr :on_stop, :string, required: true
  attr :on_reorder, :string, required: true
  attr :editing_task_id, :string, default: nil
  attr :edit_name, :string, default: ""

  defp all_tasks_draggable(assigns) do
    ~H"""
    <div
      id="task-slots"
      phx-hook=".TaskListSortable"
      data-reorder-event={@on_reorder}
      class="space-y-1"
    >
      <%= for task <- @tasks do %>
        <%= if @editing_task_id == to_string(task.id) do %>
          <div class="task-slot border border-primary rounded-lg p-2" data-task-id={task.id}>
            <form id={"edit-form-#{task.id}"} phx-submit="save_edit" phx-target="#widget">
              <div class="flex gap-1 items-center">
                <input
                  type="text"
                  name="name"
                  value={@edit_name}
                  class="input input-xs input-bordered flex-1"
                  autofocus
                  placeholder="Task name"
                />
                <button type="submit" class="btn btn-xs btn-success">
                  Save
                </button>
                <button
                  type="button"
                  class="btn btn-xs btn-ghost"
                  phx-click="cancel_edit"
                  phx-target="#widget"
                >
                  Cancel
                </button>
                <button
                  type="button"
                  class="btn btn-xs btn-error"
                  phx-click="delete_task"
                  phx-value-task_id={task.id}
                  phx-target="#widget"
                  onclick="return confirm('Delete this task? Time entries will be preserved.')"
                >
                  <.icon name="hero-trash" class="w-3 h-3" />
                </button>
              </div>
            </form>
          </div>
        <% else %>
          <div
            class="task-slot flex items-center justify-between gap-2 py-1 px-2 rounded-lg hover:bg-base-200 cursor-grab active:cursor-grabbing border border-transparent hover:border-base-300"
            draggable="true"
            data-task-id={task.id}
            phx-dblclick="start_edit"
            phx-value-task_id={task.id}
            phx-value-name={task.name}
            phx-target="#widget"
          >
            <span class="text-sm font-medium truncate flex-1">{task.name}</span>
            <div class="flex gap-1 shrink-0" data-no-drag>
              <%= if task_running?(@active_entry, task.id) do %>
                <button
                  type="button"
                  class="btn btn-xs btn-error"
                  phx-click={@on_stop}
                  phx-target="#widget"
                >
                  Stop
                </button>
              <% else %>
                <button
                  type="button"
                  id={"widget-play-#{task.id}"}
                  class="btn btn-xs btn-success"
                  phx-click={@on_play}
                  phx-value-task_id={task.id}
                  phx-target="#widget"
                >
                  Play
                </button>
              <% end %>
            </div>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp task_running?(%{task_type_id: id}, task_id), do: id == task_id
  defp task_running?(%{task_type: %{id: id}}, task_id), do: id == task_id
  defp task_running?(_, _), do: false

  defp format_elapsed(seconds) do
    h = div(seconds, 3600)
    m = div(rem(seconds, 3600), 60)
    s = rem(seconds, 60)

    :io_lib.format("~2..0B:~2..0B:~2..0B", [h, m, s]) |> to_string()
  end
end
