defmodule Mix.Tasks.AshBaml.Gen.Types do
  use Mix.Task

  @shortdoc "Generates Ash type modules from BAML schemas"

  @moduledoc """
  Generates explicit Ash type modules from BAML schema definitions.

  ## Usage

      $ mix ash_baml.gen.types MyApp.BamlClient
      $ mix ash_baml.gen.types MyApp.BamlClient --dry-run
      $ mix ash_baml.gen.types MyApp.BamlClient --verbose

  ## Arguments

  - `client_module` - The BAML client module to generate types from

  ## Options

  - `--dry-run` - Preview what would be generated without writing files
  - `--verbose` - Show detailed output during generation
  - `--output-dir` - Custom output directory (default: lib/)

  ## Generated Files

  For each BAML class, generates an Ash.TypedStruct module.
  For each BAML enum, generates an Ash.Type.Enum module.

  Example:

      # BAML class
      class WeatherTool {
        city string
        units string
      }

      # Generated module
      defmodule MyApp.BamlClient.Types.WeatherTool do
        use Ash.TypedStruct

        typed_struct do
          field :city, :string
          field :units, :string
        end
      end

  All generated files are placed in the `Types` submodule of your BAML client.
  """

  @switches [
    dry_run: :boolean,
    verbose: :boolean,
    output_dir: :string
  ]

  @aliases [
    d: :dry_run,
    v: :verbose,
    o: :output_dir
  ]

  def run(args) do
    Mix.Task.run("compile")

    {opts, argv, _} = OptionParser.parse(args, switches: @switches, aliases: @aliases)

    case argv do
      [client_module_str] ->
        client_module = Module.concat([client_module_str])
        generate_types(client_module, opts)

      _ ->
        Mix.shell().error("Usage: mix ash_baml.gen.types <ClientModule>")
        Mix.shell().info(@moduledoc)
    end
  end

  defp generate_types(client_module, opts) do
    verbose? = Keyword.get(opts, :verbose, false)
    output_dir = Keyword.get(opts, :output_dir, "lib")

    log(verbose?, "Loading BAML configuration from #{inspect(client_module)}")

    case AshBaml.BamlParser.get_baml_path(client_module) do
      {:ok, baml_path} ->
        log(verbose?, "BAML source path: #{baml_path}")

        log(verbose?, "Parsing BAML schema...")

        case AshBaml.BamlParser.parse_schema(baml_path) do
          {:ok, schema} ->
            generate_from_schema(client_module, schema, output_dir, opts)

          {:error, reason} ->
            Mix.shell().error("Failed to parse BAML schema: #{reason}")
        end

      {:error, reason} ->
        Mix.shell().error(reason)
    end
  end

  defp generate_from_schema(client_module, schema, output_dir, opts) do
    verbose? = Keyword.get(opts, :verbose, false)
    dry_run? = Keyword.get(opts, :dry_run, false)

    classes = AshBaml.BamlParser.extract_classes(schema)
    enums = AshBaml.BamlParser.extract_enums(schema)

    types_module = Module.concat(client_module, Types)

    Mix.shell().info("Generating types for #{inspect(client_module)}")
    Mix.shell().info("  Classes: #{map_size(classes)}")
    Mix.shell().info("  Enums: #{map_size(enums)}")
    Mix.shell().info("")

    unless dry_run? do
      {first_class_name, _} = Enum.at(classes, 0) || {"Temp", %{}}
      sample_module = Module.concat(types_module, first_class_name)
      types_dir = AshBaml.CodeWriter.module_to_path(sample_module, output_dir) |> Path.dirname()
      AshBaml.CodeWriter.ensure_types_directory(types_dir)
    end

    class_results =
      Enum.map(classes, fn {class_name, class_def} ->
        target_module = Module.concat(types_module, class_name)
        log(verbose?, "Generating TypedStruct: #{inspect(target_module)}")

        module_code =
          AshBaml.TypeGenerator.generate_typed_struct(
            class_name,
            class_def,
            target_module,
            source_file: "baml_src/..."
          )

        write_or_preview(module_code, target_module, output_dir, dry_run?, verbose?)
      end)

    enum_results =
      Enum.map(enums, fn {enum_name, variants} ->
        target_module = Module.concat(types_module, enum_name)
        log(verbose?, "Generating Enum: #{inspect(target_module)}")

        module_code =
          AshBaml.TypeGenerator.generate_enum(
            enum_name,
            variants,
            target_module,
            source_file: "baml_src/..."
          )

        write_or_preview(module_code, target_module, output_dir, dry_run?, verbose?)
      end)

    Mix.shell().info("")

    if dry_run? do
      Mix.shell().info("Dry run complete. No files were written.")
    else
      total = length(class_results) + length(enum_results)
      Mix.shell().info("Successfully generated #{total} type modules.")
      Mix.shell().info("")
      Mix.shell().info("Next steps:")
      Mix.shell().info("  1. Review the generated files")
      Mix.shell().info("  2. Update your Ash resource actions to use the new types")
      Mix.shell().info("  3. Run mix compile to verify everything works")
    end
  end

  defp write_or_preview(module_code, target_module, output_dir, dry_run?, verbose?) do
    if dry_run? do
      log(verbose?, "  [DRY RUN] Would write:")
      log(verbose?, String.slice(module_code, 0..200) <> "...")
      {:ok, :dry_run}
    else
      case AshBaml.CodeWriter.write_module(target_module, module_code, output_dir) do
        {:ok, file_path} ->
          Mix.shell().info("  ✓ #{file_path}")
          {:ok, file_path}

        error ->
          error
      end
    end
  end

  defp log(true, message), do: Mix.shell().info(message)
  defp log(false, _message), do: :ok
end
