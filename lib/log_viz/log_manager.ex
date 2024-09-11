defmodule LogViz.LogManager do
  def fetch_logs(nil, num_logs) do
    RingLogger.Server.tail(num_logs)
    |> add_ids()
  end

  def fetch_logs(filter, num_logs) do
    regex = Regex.compile!(filter, [:caseless])

    all_logs = RingLogger.get(0, 0)

    Enum.filter(all_logs, &Regex.match?(regex, &1.message))
    |> Enum.take(num_logs)
    |> add_ids()
  end

  def add_ids(logs) when is_list(logs) do
    Enum.map(logs, &Map.put(&1, :__id__, :erlang.phash2(&1)))
  end
end
