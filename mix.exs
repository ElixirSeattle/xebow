defmodule Xebow.MixProject do
  use Mix.Project

  @app :xebow
  @version "0.1.0"
  @all_targets [:keybow, :excalibur]

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.10",
      archives: [nerves_bootstrap: "~> 1.8"],
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      build_embedded: true,
      aliases: aliases(),
      deps: deps(),
      docs: [extras: ["README.md"]],
      releases: [{@app, release()}],
      preferred_cli_target: [
        run: :host,
        test: :host,
        dialyzer: :keybow,
        docs: :keybow
      ],
      dialyzer: [
        ignore_warnings: "dialyzer.ignore.exs",
        list_unused_filters: true,
        plt_add_apps: [:mix],
        plt_file: {:no_warn, plt_file_path()}
      ]
    ]
  end

  # Path to the dialyzer .plt file.
  defp plt_file_path do
    [Mix.Project.build_path(), "plt", "dialyxir.plt"]
    |> Path.join()
    |> Path.expand()
  end

  # Starting nerves_bootstrap adds the required aliases to Mix.Project.config()
  # Aliases are only added if MIX_TARGET is set.
  def bootstrap(args) do
    Application.start(:nerves_bootstrap)
    Mix.Task.run("loadconfig", args)
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Xebow.Application, []},
      extra_applications: [:logger, :runtime_tools, :os_mon]
    ]
  end

  defp aliases do
    [
      "assets.compile": assets_compile(),
      "assets.install": "cmd npm install --prefix ./assets",
      "docs.show": "do docs, cmd xdg-open doc/index.html",
      firmware: ["assets.compile", "firmware"],
      "firmware.upload": ["firmware", "upload"],
      loadconfig: [&bootstrap/1],
      upload: "upload xebow.local",
      setup: ["deps.get", "assets.install"],
      test: ["cmd rm -rf priv/settings_test", "test"]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Dependencies for all targets
      {:nerves, "~> 1.6.3", runtime: false},
      {:shoehorn, "~> 0.6"},
      {:ring_logger, "~> 0.8"},
      {:toolshed, "~> 0.2"},
      {:chameleon, "~> 2.2"},
      {:afk, "~> 0.3"},
      {:dialyxir, "~> 1.0.0", only: :dev, runtime: false},
      {:ex_doc, "~> 0.22", only: :dev, runtime: false},
      {:mox, "~> 0.5", only: :test},
      {:credo, "~> 1.4", only: [:dev, :test], runtime: false, targets: [:host]},

      # phoenix + live-view:
      {:floki, ">= 0.0.0", only: :test},
      {:jason, "~> 1.0"},
      {:phoenix_html, "~> 2.14"},
      {:phoenix_live_dashboard, "~> 0.2"},
      {:phoenix_live_reload, "~> 1.2", only: :dev, targets: :host},
      {:phoenix_live_view, "~> 0.14"},
      {:phoenix, "~> 1.5.3"},
      {:plug_cowboy, "~> 2.3"},
      {:telemetry_metrics, "~> 0.5"},
      {:telemetry_poller, "~> 0.5"},

      # Dependencies for all targets except :host
      {:nerves_runtime, "~> 0.11", targets: @all_targets, override: true},
      {:nerves_pack, "~> 0.3", targets: @all_targets},
      {:vintage_net_wizard, "~> 0.2", targets: @all_targets, only: [:dev, :prod]},
      {:circuits_gpio, "~> 0.4", targets: @all_targets},
      {:circuits_spi, "~> 0.1", targets: @all_targets},
      {:usb_gadget, github: "nerves-project/usb_gadget", ref: "master", targets: @all_targets},

      # Dependencies for specific targets
      {:nerves_system_keybow,
       github: "ElixirSeattle/nerves_system_keybow",
       ref: "v2.0.0-rc.0+keybow.1",
       runtime: false,
       targets: [:keybow, :excalibur]}
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def release do
    [
      overwrite: true,
      cookie: "#{@app}_cookie",
      include_erts: &Nerves.Release.erts/0,
      steps: [&Nerves.Release.init/1, :assemble],
      strip_beams: Mix.env() == :prod
    ]
  end

  defp assets_compile do
    compile_command = "cmd npm run deploy --prefix ./assets"

    if File.dir?("./assets/node_modules") do
      compile_command
    else
      ["assets.install", compile_command]
    end
  end
end
