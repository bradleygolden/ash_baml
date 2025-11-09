defmodule AshBaml.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :ash_baml,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() != :test,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      dialyzer: dialyzer(),
      docs: docs(),
      package: package(),
      aliases: aliases(),
      description:
        "Ash integration for BAML (Boundary ML) functions, enabling type-safe LLM interactions"
    ]
  end

  # Specifies which paths to compile per environment
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: []
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ash, "~> 3.0"},
      {:baml_elixir, "~> 1.0.0-pre.23"},
      {:rustler, "~> 0.0", runtime: false},
      {:jason, "~> 1.4"},
      {:spark, "~> 2.2"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:igniter, "~> 0.3", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false}
    ]
  end

  defp dialyzer do
    [
      # Ignore Mix.Task and Mix.shell since they're runtime-only build tools
      plt_add_apps: [:mix],
      # Suppress warnings about Mix functions that Dialyzer can't find
      flags: [:error_handling, :underspecs]
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: "https://github.com/bradleygolden/ash_baml",
      homepage_url: "https://github.com/bradleygolden/ash_baml",
      extra_section: "GUIDES",
      extras: [
        {"README.md", title: "Home"},
        # DSL Documentation (auto-generated)
        {"documentation/dsls/DSL-AshBaml.Resource.md", title: "DSL: AshBaml.Resource"},
        # Tutorials
        "documentation/tutorials/01-get-started.md",
        "documentation/tutorials/02-structured-output.md",
        "documentation/tutorials/03-tool-calling.md",
        "documentation/tutorials/04-building-an-agent.md",
        # Topics
        "documentation/topics/why-ash-baml.md",
        "documentation/topics/type-generation.md",
        "documentation/topics/actions.md",
        "documentation/topics/telemetry.md",
        "documentation/topics/patterns.md",
        # How-to Guides
        "documentation/how-to/call-baml-function.md",
        "documentation/how-to/implement-tool-calling.md",
        "documentation/how-to/add-streaming.md",
        "documentation/how-to/configure-telemetry.md",
        "documentation/how-to/build-agentic-loop.md",
        "documentation/how-to/customize-actions.md"
      ],
      groups_for_extras: [
        Tutorials: ~r/documentation\/tutorials\/.*/,
        Topics: ~r/documentation\/topics\/.*/,
        "How-to": ~r/documentation\/how-to\/.*/,
        Reference: ~r/documentation\/dsls\/.*/
      ],
      groups_for_modules: [
        Core: [
          AshBaml,
          AshBaml.Resource,
          AshBaml.Helpers,
          AshBaml.Dsl,
          AshBaml.Info
        ],
        Actions: [
          AshBaml.Actions.CallBamlFunction,
          AshBaml.Actions.CallBamlStream
        ],
        Types: [
          AshBaml.Type.Stream,
          AshBaml.TypeGenerator
        ],
        Telemetry: [
          AshBaml.Telemetry
        ],
        Utilities: [
          AshBaml.BamlParser,
          AshBaml.FunctionIntrospector,
          AshBaml.CodeWriter
        ],
        Transformers: [
          AshBaml.Transformers.ImportBamlFunctions
        ],
        "Mix Tasks": [
          Mix.Tasks.AshBaml.Install,
          Mix.Tasks.AshBaml.Gen.Types
        ]
      ],
      skip_undefined_reference_warnings_on: [
        "README.md"
      ],
      before_closing_head_tag: fn
        :html ->
          """
          <style>
            .livebook-badge-container + pre { display: none; }
          </style>
          """

        _ ->
          ""
      end
    ]
  end

  defp package do
    [
      name: "ash_baml",
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/bradleygolden/ash_baml",
        "BAML Documentation" => "https://docs.boundaryml.com",
        "Ash Framework" => "https://hexdocs.pm/ash"
      },
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE)
    ]
  end

  defp aliases do
    [
      docs: [
        "spark.cheat_sheets --extensions AshBaml.Resource",
        "docs",
        "spark.replace_doc_links"
      ]
    ]
  end
end
