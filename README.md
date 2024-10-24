# LogViz

**TODO: Add description**


## Installation

Install by adding `log_viz` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:log_viz, github: "axelson/log_viz"},
  ]
end
```

Add log viz to your router (you may want to add it to an admin-only scope)
import LogViz.Router

``` elixir
scope "/" do
  pipe_through :admin_browser # or whatever pipeline you're using
  import LogViz.Router
  # ^^^ Add this line

  log_viz "/logs"
  # ^^^ Add this line
end
```

Ensure that you have LiveView setup: https://github.com/phoenixframework/phoenix_live_dashboard?tab=readme-ov-file#2-configure-liveview

LogViz is built on top of RingLogger, so ensure that it is added to your logger backends configuration:
`config :logger, backends: [:console, RingLogger]`

Alternatively, you can start it manually at runtime

``` elixir
Logger.add_backend(RingLogger)
Logger.configure_backend(RingLogger, max_size: 1024)
```

See the RingLogger readme for full configuration information https://github.com/nerves-project/ring_logger
