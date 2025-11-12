defmodule AshBaml.TypeGenerator do
  @moduledoc """
  Generates Ash type module definitions from BAML type metadata.

  This module takes parsed BAML type information and produces Elixir code
  for Ash.TypedStruct and Ash.Type.Enum modules.
  """

  @doc """
  Generates an Ash.TypedStruct module definition from a BAML class.

  ## Parameters
  - `class_name` - String name of the BAML class
  - `class_def` - Map with "fields" and "dynamic" keys
  - `target_module` - Module name for the generated type
  - `opts` - Options including `:source_file`

  ## Returns
  - String containing the complete module definition
  """
  def generate_typed_struct(class_name, class_def, target_module, opts \\ []) do
    fields = class_def["fields"] || %{}
    source_file = Keyword.get(opts, :source_file, "unknown")

    base_module = get_base_module(target_module)

    field_defs =
      fields
      |> Enum.map(fn {field_name, field_type} ->
        elixir_type = baml_type_to_elixir_type(field_type, base_module)
        snake_field = Macro.underscore(field_name)

        description = get_field_description(field_type)

        field_opts =
          [
            allow_nil?: optional?(field_type),
            description: description
          ]
          |> Enum.reject(fn {_k, v} -> is_nil(v) end)

        {snake_field, elixir_type, field_opts}
      end)

    """
    defmodule #{inspect(target_module)} do
      use Ash.TypedStruct

      @moduledoc \"\"\"
      Generated from BAML class: #{class_name}
      Source: #{source_file}

      This struct is automatically generated from BAML schema definitions.
      Do not edit directly - modify the BAML file and regenerate.
      \"\"\"

      typed_struct do
    #{generate_field_definitions(field_defs)}
      end
    end
    """
  end

  @doc """
  Generates an Ash.Type.Enum module definition from a BAML enum.

  ## Parameters
  - `enum_name` - String name of the BAML enum
  - `variants` - List of variant strings
  - `target_module` - Module name for the generated type
  - `opts` - Options including `:source_file`

  ## Returns
  - String containing the complete module definition
  """
  def generate_enum(enum_name, variants, target_module, opts \\ []) do
    source_file = Keyword.get(opts, :source_file, "unknown")

    atom_variants = Enum.map(variants, &variant_to_atom/1)

    variant_docs =
      variants
      |> Enum.zip(atom_variants)
      |> Enum.map_join("\n", fn {original, atom} ->
        "  - `:#{atom}` - #{original}"
      end)

    """
    defmodule #{inspect(target_module)} do
      use Ash.Type.Enum, values: #{inspect(atom_variants)}

      @moduledoc \"\"\"
      Generated from BAML enum: #{enum_name}
      Source: #{source_file}

      ## Values
    #{variant_docs}

      This enum is automatically generated from BAML schema definitions.
      Do not edit directly - modify the BAML file and regenerate.
      \"\"\"
    end
    """
  end

  defp generate_field_definitions(fields) do
    Enum.map_join(fields, "\n", fn {name, type, opts} ->
      opts_str = if opts == [], do: "", else: ", " <> format_field_opts(opts)
      "    field :#{name}, #{inspect(type)}#{opts_str}"
    end)
  end

  defp format_field_opts(opts) do
    Enum.map_join(opts, ", ", fn {k, v} -> "#{k}: #{inspect(v)}" end)
  end

  defp baml_type_to_elixir_type({:primitive, type}, _base_module), do: primitive_to_elixir(type)

  defp baml_type_to_elixir_type({:list, inner}, base_module),
    do: {:array, baml_type_to_elixir_type(inner, base_module)}

  defp baml_type_to_elixir_type({:optional, inner}, base_module),
    do: baml_type_to_elixir_type(inner, base_module)

  defp baml_type_to_elixir_type({:class, name}, base_module) do
    # Convert BAML class name to full module name
    # e.g., "Task" with base TodoApp.BamlClient.Types -> TodoApp.BamlClient.Types.Task
    Module.concat(base_module, name)
  end

  defp baml_type_to_elixir_type({:enum, name}, base_module) do
    # Convert BAML enum name to full module name
    # e.g., "Priority" with base TodoApp.BamlClient.Types -> TodoApp.BamlClient.Types.Priority
    Module.concat(base_module, name)
  end

  defp baml_type_to_elixir_type({:map, _key_type, _value_type}, _base_module), do: :map

  defp baml_type_to_elixir_type(_, _base_module), do: :any

  defp primitive_to_elixir(:string), do: :string
  defp primitive_to_elixir(:integer), do: :integer
  defp primitive_to_elixir(:float), do: :float
  defp primitive_to_elixir(:boolean), do: :boolean
  defp primitive_to_elixir(nil), do: :any
  defp primitive_to_elixir(_), do: :any

  defp optional?({:optional, _}), do: true
  defp optional?(_), do: false

  defp get_field_description({:primitive, _type, meta}) when is_map(meta) do
    Map.get(meta, "description")
  end

  defp get_field_description(_), do: nil

  # Safe: converts enum variant names from BAML schemas (trusted developer input)
  # Input strings come from parsed BAML files, not runtime user input
  # sobelow_skip ["DOS.StringToAtom"]
  defp variant_to_atom(string) do
    string
    |> Macro.underscore()
    |> String.to_atom()
  end

  defp get_base_module(target_module) do
    parts = Module.split(target_module)
    base_parts = Enum.slice(parts, 0..-2//1)
    Module.concat(base_parts)
  end
end
