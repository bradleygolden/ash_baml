defmodule AshBaml.CodeWriter do
  @moduledoc """
  Handles writing and formatting generated Elixir code files.
  """

  @doc """
  Writes a module definition to a file.

  ## Parameters
  - `module_name` - Full module name (e.g., MyApp.Types.Foo)
  - `module_code` - String containing the module definition
  - `base_path` - Base directory for output (e.g., "lib")

  ## Returns
  - `{:ok, file_path}` on success
  - `{:error, reason}` on failure
  """
  # Safe: paths derived from module names via Module.split() and Macro.underscore()
  # Module names come from BAML schemas (trusted developer input), not user input
  # sobelow_skip ["Traversal.FileModule"]
  def write_module(module_name, module_code, base_path) do
    file_path = module_to_path(module_name, base_path)
    dir_path = Path.dirname(file_path)

    with :ok <- File.mkdir_p(dir_path),
         {:ok, formatted_code} <- format_code(module_code),
         :ok <- File.write(file_path, formatted_code) do
      {:ok, file_path}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp format_code(code) do
    {:ok, Code.format_string!(code)}
  rescue
    e -> {:error, "Failed to format code: #{Exception.message(e)}"}
  end

  @doc """
  Converts a module name to a file path.

  Example: `MyApp.BamlClient.Types.Foo` -> "lib/my_app/baml_client/types/foo.ex"
  """
  def module_to_path(module_name, base_path) do
    parts =
      module_name
      |> Module.split()
      |> Enum.map(&Macro.underscore/1)

    filename = List.last(parts) <> ".ex"
    dir_parts = Enum.slice(parts, 0..-2//1)

    Path.join([base_path | dir_parts] ++ [filename])
  end

  @doc """
  Ensures a .gitkeep or README exists in the types directory.

  ## Returns
  - `:ok` on success
  - `{:error, reason}` on failure
  """
  # Safe: types_dir comes from base_path (trusted config) + module names from BAML schemas
  # README path is derived from types_dir with static filename
  # sobelow_skip ["Traversal.FileModule"]
  def ensure_types_directory(types_dir) do
    readme_path = Path.join(types_dir, "README.md")

    readme_content = """
    # Generated Ash Types from BAML

    This directory contains Ash type modules automatically generated from BAML schemas.

    **Do not edit these files directly.** Instead:
    1. Modify the BAML schema files
    2. Run `mix ash_baml.gen.types YourBamlClient`
    3. Review and commit the changes

    Generated files are checked into version control to ensure:
    - IDE tooling works correctly (autocomplete, go-to-definition)
    - Type definitions are visible and reviewable in PRs
    - No runtime surprises from hidden generated code
    """

    with :ok <- File.mkdir_p(types_dir),
         :ok <- maybe_write_readme(readme_path, readme_content) do
    end
  end

  # sobelow_skip ["Traversal.FileModule"]
  defp maybe_write_readme(readme_path, content) do
    if File.exists?(readme_path) do
      :ok
    else
      File.write(readme_path, content)
    end
  end
end
