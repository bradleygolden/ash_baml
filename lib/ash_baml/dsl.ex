defmodule AshBaml.Dsl do
  @moduledoc """
  DSL for configuring BAML integration in Ash resources.
  """

  @telemetry %Spark.Dsl.Section{
    name: :telemetry,
    describe: """
    Configure telemetry for BAML function calls.

    Telemetry is opt-in and disabled by default. When enabled, emits
    `:telemetry` events for observability into LLM interactions.

    ## Events Emitted

    - `[:ash_baml, :call, :start]` - Before BAML function call
    - `[:ash_baml, :call, :stop]` - After successful call
    - `[:ash_baml, :call, :exception]` - On error

    ## Example

        telemetry do
          enabled true
          metadata [:function_name, :resource]
          sample_rate 1.0
        end
    """,
    examples: [
      """
      telemetry do
        enabled true
        prefix [:my_app, :ai]
        metadata [:function_name, :resource, :action]
        sample_rate 0.1  # Track 10% of calls
      end
      """
    ],
    schema: [
      enabled: [
        type: :boolean,
        default: false,
        doc: """
        Enable telemetry for BAML function calls.

        When `false`, no collectors are created and no telemetry events
        are emitted, resulting in zero overhead.

        Default: `false`
        """
      ],
      prefix: [
        type: {:list, :atom},
        default: [:ash_baml],
        doc: """
        Event name prefix for telemetry events.

        Events will be named `prefix ++ [:call, event_type]`.

        Default: `[:ash_baml]` (events: `[:ash_baml, :call, :start]`, etc.)
        """
      ],
      events: [
        type: {:list, {:in, [:start, :stop, :exception]}},
        default: [:start, :stop, :exception],
        doc: """
        Which telemetry events to emit.

        Allowed values: `:start`, `:stop`, `:exception`

        Default: `[:start, :stop, :exception]`
        """
      ],
      metadata: [
        type: {:list, :atom},
        default: [],
        doc: """
        Additional metadata fields to include in telemetry events.

        Safe fields (always included):
        - `:resource` - The Ash resource module
        - `:action` - The action name
        - `:function_name` - The BAML function name
        - `:collector_name` - The collector reference identifier

        Opt-in fields (must be explicitly listed):
        - `:llm_client` - The LLM client used
        - `:stream` - Whether this was a streaming call

        Default: `[]` (only safe fields included)
        """
      ],
      sample_rate: [
        type: :float,
        default: 1.0,
        doc: """
        Sampling rate for telemetry (0.0 - 1.0).

        Use lower rates for high-volume operations to reduce overhead.
        - `1.0` = 100% of calls tracked
        - `0.1` = 10% of calls tracked
        - `0.0` = effectively disables telemetry

        Default: `1.0`
        """
      ],
      collector_name: [
        type: {:or, [:string, {:fun, 1}, nil]},
        default: nil,
        doc: """
        Custom name for collectors.

        Can be:
        - A string: `"my-collector"`
        - A function that receives the input and returns a string:
          `fn input -> "\#{input.resource}-\#{input.action.name}" end`

        If not provided, a unique name is generated:
        `"ResourceModule-FunctionName-unique_integer"`

        Default: `nil` (auto-generated)
        """
      ]
    ]
  }

  @baml %Spark.Dsl.Section{
    name: :baml,
    describe: """
    Configure BAML client integration for this resource.

    ## Example

        baml do
          client :support

          telemetry do
            enabled true
          end
        end
    """,
    examples: [
      """
      # Recommended: config-driven client
      baml do
        client :support
        import_functions [:AnalyzeTicket]
      end
      """,
      """
      # Legacy: explicit module
      baml do
        client_module MyApp.BamlClient
      end
      """,
      """
      # With telemetry
      baml do
        client :support

        telemetry do
          enabled true
          metadata [:function_name, :llm_client]
        end
      end
      """
    ],
    schema: [
      client: [
        type: :atom,
        doc: """
        Client identifier that references a client configured in application config.

        This is the recommended approach for defining BAML clients. Configure your
        clients in config and reference them by identifier:

            # config/config.exs
            config :ash_baml,
              clients: [
                support: {MyApp.BamlClients.Support, baml_src: "baml_src/support"},
                content: {MyApp.BamlClients.Content, baml_src: "baml_src/content"}
              ]

            # In your resource
            baml do
              client :support
              import_functions [:AnalyzeTicket]
            end

        The client module will be automatically generated at compile time using
        the configured module name and baml_src path. Multiple resources can
        share the same client by using the same identifier.

        Either `client` or `client_module` must be provided, but not both.
        """
      ],
      client_module: [
        type: :atom,
        doc: """
        The module that uses `BamlElixir.Client` to define BAML functions.

        This is the legacy approach where you manually create a client module file.
        Consider using `client` with config-based clients instead.

        Either `client` or `client_module` must be provided, but not both.
        """
      ],
      import_functions: [
        type: {:list, :atom},
        default: [],
        doc: """
        List of BAML function names to import as Ash actions.

        For each function listed, two actions are automatically generated:

        1. Regular action: `:function_name` - Returns the complete result
        2. Streaming action: `:function_name_stream` - Returns a Stream

        The function names must match BAML function definitions, and their
        return types must have corresponding generated types in
        `ClientModule.Types`.

        ## Example

            baml do
              client :support
              import_functions [:ExtractTasks, :SummarizeTasks]
            end

        This generates 4 actions:
        - `:extract_tasks` - Regular action
        - `:extract_tasks_stream` - Streaming action
        - `:summarize_tasks` - Regular action
        - `:summarize_tasks_stream` - Streaming action

        ## Requirements

        Before importing functions, you must:

        1. Define BAML functions in your `baml_src/` directory
        2. Run `mix ash_baml.gen.types YourClient` to generate types
        3. Ensure types exist in `YourClient.Types` namespace

        The transformer will validate at compile-time that:
        - Functions exist in the BAML client
        - Return types have been generated
        - Argument types are valid
        """
      ]
    ],
    sections: [@telemetry]
  }

  @doc false
  def baml, do: @baml
end
