defmodule LogViz.MixProject do
  use Mix.Project

  def project do
    [
      app: :log_viz,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {LogViz.Application, []}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "cmd --cd assets npm install"],
      dev: "run --no-halt dev.exs",
      "assets.build": [
        "esbuild default --minify",
        "sass default --no-source-map --style=compressed"
      ],
      "assets.watch": [
        "esbuild default --watch"
      ],
      "sass.watch": [
        "sass default --no-source-map --watch"
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ring_logger, "~> 0.11.3"},
      {:phoenix_live_view, "~> 0.19 or ~> 1.0", phoenix_live_view_opts()},
      {:esbuild, "~> 0.5", only: :dev},
      {:dart_sass, "~> 0.7", only: :dev}

      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  defp phoenix_live_view_opts do
    if path = System.get_env("LIVE_VIEW_PATH") do
      [path: path]
    else
      []
    end
  end
end
