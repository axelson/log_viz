import Config

if config_env() == :dev do
  config :esbuild,
    # version: "0.14.41",
    version: "0.23.1",
    default: [
      args:
        ~w(js/app.js --bundle --minify --sourcemap=external --target=es2020 --outdir=../dist/js),
      cd: Path.expand("../assets", __DIR__),
      env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
    ]

  config :dart_sass,
    version: "1.61.0",
    default: [
      args: ~w(--load-path=node_modules --no-source-map css/app.scss ../dist/css/app.css),
      cd: Path.expand("../assets", __DIR__)
    ]
end
