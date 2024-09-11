defmodule LogViz.LogsLive do
  use Phoenix.LiveView, log: false
  require Logger
  alias LogViz.LogManager

  # @num_logs 200
  @num_logs 30

  @standard_metadata_keys [
    # Clearly documented
    :application,
    :mfa,
    :file,
    :line,
    :pid,
    :initial_call,
    :registered_name,
    :process_label,
    :domain,
    :crash_reason,

    # Not clearly documented
    :erl_level,
    :gl,
    :time,
    :module,
    :function,
    :ansi_color
  ]

  @ring_logger_metadata_keys [:index]

  @standard_phoenix_metadata_keys [:request_id, :request_path]

  def init(opts), do: {:ok, opts}

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    if connected?(socket) do
      RingLogger.Server.attach_client(self())
    end

    socket =
      assign(socket,
        logs: fetch_logs(nil),
        filter: nil,
        selected_log: nil
      )

    socket = assign(socket, selected_log: hd(socket.assigns.logs))

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="log-page">
      <h2>Logs</h2>
      <div class="log-table-wrapper">
        <table class="log-table">
          <thead>
            <tr>
              <th id="timestamp-header" phx-hook="TimestampWidthHook" phx-update="ignore">
                Timestamp
              </th>
              <th>Log</th>
            </tr>
          </thead>
          <tbody>
            <%= for log <- @logs do %>
              <.render_log log={log} selected={log == @selected_log} />
            <% end %>
          </tbody>
        </table>
      </div>
      <div class="filter-container">
        <form phx-change="set-filter" phx-submit="save">
          <input id="filter-input" type="text" name="form[filter]" phx-throttle="90" value={@filter} />
        </form>
        <button phx-click="clear-filter">Clear</button>
      </div>
      <%= if @selected_log do %>
        <.render_selected_log selected_log={@selected_log} />
      <% end %>
    </div>
    """
  end

  defp render_log(assigns) do
    ~H"""
    <tr class={"log selected-#{@selected}"} phx-click="select-log" phx-value-log-id={@log.__id__}>
      <td class="timestamp"><%= render_timestamp(@log.timestamp) %></td>
      <td class={"log-message level-#{@log.level}"}>
        <%= @log.message %>
      </td>
    </tr>
    """
  end

  defp render_selected_log(assigns) do
    # assigns.selected_log
    # |> IO.inspect(label: "log (logs_live.ex:117)")

    ~H"""
    <div class="selected-log-panel">
      <button class="close-button" phx-click="clear-selected-log">&times;</button>
      <div
        id={"selected-log-message-#{@selected_log.__id__}"}
        class={"selected-log-message #{if long_message?(@selected_log), do: "long-message"}"}
        phx-hook="TextExpand"
        phx-update="ignore"
      >
        <%= @selected_log.message %>
        <button class="expand-button">expand</button>
      </div>
      <div class="flex">
        <div>time:</div>
        <div class="timestamp"><%= render_timestamp(@selected_log.timestamp) %></div>
      </div>
      <.render_standard_metadata metadata={@selected_log.metadata} />
      <div class="custom-metadata">
        <%= for {key, value} <- custom_metadata(@selected_log.metadata) do %>
          <div class="metadata-entry">
            <div class="metadata-key"><%= key %></div>
            <div class="metadata-value"><%= inspect(value) %></div>
          </div>
        <% end %>
      </div>
      <div class="raw-metadata">
        <%= for {key, value} <- Keyword.drop(@selected_log.metadata, Keyword.keys(custom_metadata(@selected_log.metadata))) do %>
          <div class="metadata-entry">
            <div class="metadata-key"><%= key %></div>
            <div class="metadata-value"><%= inspect(value) %></div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_standard_metadata(assigns) do
    # vscode://file/__FILE__:__LINE__
    ~H"""
    <div class="mfa">
      <%= mfa(@metadata) %>
    </div>
    <div>
      file <.file_link metadata={@metadata} />
    </div>
    """
  end

  defp file_link(assigns) do
    ~H"""
    <%= if file_link = file_link_info(@metadata) do %>
      <%= case get_values(@metadata, [:file, :line]) do %>
        <% [file, line] -> %>
          <a href={file_link}><%= file %>:<%= line %></a>
        <% _ -> %>
      <% end %>
    <% end %>
    """
  end

  defp file_link_info(metadata) do
    # FIXME: Make this configurable
    plug_editor = "vscode://file/__FILE__:__LINE__"

    case get_values(metadata, [:module, :file, :line]) do
      [module, file, line] ->
        app = get_app(module)
        source = get_source(app, module, file)

        plug_editor
        |> :binary.replace("__FILE__", URI.encode(Path.expand(source)))
        |> :binary.replace("__RELATIVEFILE__", URI.encode(file))
        |> :binary.replace("__LINE__", to_string(line))

      _ ->
        nil
    end
  end

  defp get_values(keyword_list, keys) do
    Enum.reduce_while(keys, [], fn key, values ->
      if Keyword.has_key?(keyword_list, key) do
        {:cont, [Keyword.fetch!(keyword_list, key) | values]}
      else
        {:halt, :error}
      end
    end)
    |> case do
      :error -> :error
      list -> Enum.reverse(list)
    end
  end

  defp get_app(module) do
    case :application.get_application(module) do
      {:ok, app} -> app
      :undefined -> nil
    end
  end

  # From Plug.Debugger
  defp get_source(app, module, file) do
    cond do
      File.regular?(file) ->
        file

      File.regular?("apps/#{app}/#{file}") ->
        "apps/#{app}/#{file}"

      source = module && Code.ensure_loaded?(module) && module.module_info(:compile)[:source] ->
        to_string(source)

      true ->
        file
    end
  end

  defp mfa(metadata) do
    case Keyword.get(metadata, :mfa) do
      {module, function, arity} ->
        "#{Macro.to_string(module)}.#{function}/#{arity}"

      _ ->
        ""
    end
  end

  defp custom_metadata(metadata) do
    metadata
    |> Keyword.drop(@standard_metadata_keys)
    |> Keyword.drop(@ring_logger_metadata_keys)
    |> Keyword.drop(@standard_phoenix_metadata_keys)
  end

  defp long_message?(log) do
    byte_size(log.message) >= 256
  end

  @impl Phoenix.LiveView
  def handle_event("set-filter", params, socket) do
    %{"form" => %{"filter" => filter}} = params

    socket = assign(socket, logs: fetch_logs(filter), filter: filter)

    {:noreply, socket}
  end

  def handle_event("clear-filter", _params, socket) do
    socket = assign(socket, logs: fetch_logs(nil), filter: nil)

    {:noreply, socket}
  end

  def handle_event("select-log", params, socket) do
    %{"log-id" => log_id} = params
    log_id = String.to_integer(log_id)

    if selected_log = Enum.find(socket.assigns.logs, &(&1.__id__ == log_id)) do
      socket = assign(socket, selected_log: selected_log)

      {:noreply, socket}
    else
      Logger.error("Unable to find log #{log_id}")

      {:noreply, socket}
    end
  end

  def handle_event("clear-selected-log", _params, socket) do
    socket = assign(socket, selected_log: nil)
    {:noreply, socket}
  end

  def handle_event(event, _params, socket) do
    Logger.warning("Unhandled event: #{inspect(event)}")
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:log, _log}, socket) do
    socket = assign(socket, logs: fetch_logs(socket.assigns.filter))
    {:noreply, socket}
  end

  def handle_info(message, socket) do
    Logger.warning("Ignoring unhandled message: #{inspect(message)}")
    {:noreply, socket}
  end

  def render_timestamp({{year, month, day}, {hour, minute, second, microsecond}}) do
    naive_date_time =
      NaiveDateTime.from_erl!(
        {{year, month, day}, {hour, minute, second}},
        {microsecond * 1000, 3}
      )

    Calendar.strftime(naive_date_time, "%I:%M:%S.%f")
  end

  defp fetch_logs(filter) do
    LogManager.fetch_logs(filter, @num_logs)
  end
end
