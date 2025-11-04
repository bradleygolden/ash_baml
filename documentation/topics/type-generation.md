# Type Generation

Deep dive into how BAML types map to Ash types and how the type generator works.

## Overview

The `mix ash_baml.gen.types` task generates Ash-compatible type modules from your BAML schemas. This gives you:

1. **Type Safety**: Compile-time checking of BAML function return types
2. **IDE Support**: Autocomplete and inline documentation
3. **Runtime Validation**: Ash's type system validates data at runtime
4. **Composability**: Generated types work with Ash resources, GraphQL, JSON:API, etc.

## Running the Generator

```bash
# Generate types for your BAML client
mix ash_baml.gen.types MyApp.BamlClient

# With custom output directory
mix ash_baml.gen.types MyApp.BamlClient --output-dir lib/my_app/custom_types
```

The generator:
1. Reads your BAML schema from `baml_src/`
2. Parses class and enum definitions
3. Generates Elixir modules in `lib/<app>/<client>/types/`
4. Creates `Ash.TypedStruct` for classes and `Ash.Type.Enum` for enums

## Type Mapping Reference

### Primitive Types

| BAML Type | Ash Type | Elixir Type | Notes |
|-----------|----------|-------------|-------|
| `string` | `:string` | `String.t()` | UTF-8 strings |
| `int` | `:integer` | `integer()` | 64-bit integers |
| `float` | `:float` | `float()` | IEEE 754 floats |
| `bool` | `:boolean` | `boolean()` | `true` or `false` |

### Optional Types

| BAML Type | Ash Type | Generated Field |
|-----------|----------|-----------------|
| `string?` | `:string` with `allow_nil?: true` | `field :name, :string, allow_nil?: true` |
| `int?` | `:integer` with `allow_nil?: true` | `field :age, :integer, allow_nil?: true` |

### Array Types

| BAML Type | Ash Type | Generated Field |
|-----------|----------|-----------------|
| `string[]` | `{:array, :string}` | `field :tags, {:array, :string}` |
| `User[]` | `{:array, MyApp.BamlClient.Types.User}` | `field :users, {:array, MyApp.BamlClient.Types.User}` |

### Class Types

**BAML:**
```baml
class User {
  name string
  email string?
  age int
}
```

**Generated Ash Type:**
```elixir
defmodule MyApp.BamlClient.Types.User do
  use Ash.TypedStruct

  typed_struct do
    field :name, :string
    field :email, :string, allow_nil?: true
    field :age, :integer
  end
end
```

### Nested Classes

**BAML:**
```baml
class Address {
  street string
  city string
  zip string
}

class User {
  name string
  address Address
}
```

**Generated:**
```elixir
defmodule MyApp.BamlClient.Types.Address do
  use Ash.TypedStruct

  typed_struct do
    field :street, :string
    field :city, :string
    field :zip, :string
  end
end

defmodule MyApp.BamlClient.Types.User do
  use Ash.TypedStruct

  typed_struct do
    field :name, :string
    field :address, MyApp.BamlClient.Types.Address
  end
end
```

### Enum Types

**BAML:**
```baml
enum Status {
  Active
  Inactive
  Suspended
}
```

**Generated:**
```elixir
defmodule MyApp.BamlClient.Types.Status do
  use Ash.Type.Enum,
    values: [:active, :inactive, :suspended]
end
```

**Conversion:**
- BAML enum values (PascalCase) → Ash atoms (snake_case)
- `Active` → `:active`
- `InProgress` → `:in_progress`

### Maps and Dictionaries

BAML map types are generated as `:map`:

**BAML:**
```baml
class Config {
  settings map<string, string>
}
```

**Generated:**
```elixir
typed_struct do
  field :settings, :map
end
```

**Note**: Ash's `:map` type accepts any key-value pairs. For stronger typing, consider using embedded resources.

## Generated File Structure

For a BAML client `MyApp.BamlClient`, types are generated in:

```
lib/
└── my_app/
    └── baml_client/
        └── types/
            ├── status.ex           # Enums
            ├── user.ex             # Classes
            ├── address.ex          # Nested classes
            └── task_list.ex        # Complex classes
```

Each file contains a single module:

```elixir
# lib/my_app/baml_client/types/user.ex
defmodule MyApp.BamlClient.Types.User do
  @moduledoc """
  Generated from BAML class: User

  ## Fields

  - `:name` - User's full name
  - `:email` - Optional email address
  - `:age` - User's age in years
  """

  use Ash.TypedStruct

  typed_struct do
    field :name, :string
    field :email, :string, allow_nil?: true
    field :age, :integer
  end
end
```

## Using Generated Types

### In BAML Actions

Generated types are automatically used as return types for BAML actions:

```elixir
defmodule MyApp.Extractor do
  use Ash.Resource,
    extensions: [AshBaml.Resource]

  baml do
    client :default
    import_functions [:ExtractUser]  # Returns MyApp.BamlClient.Types.User
  end
end
```

### In Custom Actions

Use generated types in custom action signatures:

```elixir
actions do
  action :process_user, :map do
    argument :user, MyApp.BamlClient.Types.User, allow_nil?: false

    run fn input, _ctx ->
      user = input.arguments.user
      # user.name, user.email, user.age are all type-safe
      {:ok, %{processed: true, user_name: user.name}}
    end
  end
end
```

### Pattern Matching

Generated structs support pattern matching:

```elixir
case extract_user(text) do
  {:ok, %MyApp.BamlClient.Types.User{email: nil}} ->
    {:error, "Email required"}

  {:ok, %MyApp.BamlClient.Types.User{age: age}} when age < 18 ->
    {:error, "Must be 18+"}

  {:ok, user} ->
    {:ok, user}
end
```

## Type Generator Implementation

The type generator:

1. **Parses BAML schema** using `AshBaml.BamlParser`
2. **Extracts definitions** for classes and enums
3. **Generates Elixir AST** for each type
4. **Writes files** to output directory

Key components:

### BamlParser

Reads and parses BAML files:

```elixir
{:ok, schema} = AshBaml.BamlParser.parse_schema("baml_src")

schema
|> Enum.filter(fn
  {:class, _name, _fields} -> true
  {:enum, _name, _values} -> true
  _ -> false
end)
```

### TypeGenerator

Generates Ash type modules:

```elixir
AshBaml.TypeGenerator.generate_types(
  client_module: MyApp.BamlClient,
  output_dir: "lib/my_app/baml_client/types"
)
```

### CodeWriter

Formats and writes Elixir code:

```elixir
AshBaml.CodeWriter.write_module(
  module_name: MyApp.BamlClient.Types.User,
  code: generated_ast,
  file_path: "lib/my_app/baml_client/types/user.ex"
)
```

## Customizing Generated Types

### Adding Validations

You can extend generated types with custom validations:

```elixir
# Generated type
defmodule MyApp.BamlClient.Types.User do
  use Ash.TypedStruct

  typed_struct do
    field :name, :string
    field :email, :string, allow_nil?: true
    field :age, :integer
  end

  # Add custom validation
  def validate(user) do
    cond do
      String.length(user.name) < 2 ->
        {:error, "Name too short"}

      user.age < 0 ->
        {:error, "Invalid age"}

      user.email && !String.contains?(user.email, "@") ->
        {:error, "Invalid email"}

      true ->
        :ok
    end
  end
end
```

### Adding Helper Functions

Extend generated types with domain logic:

```elixir
defmodule MyApp.BamlClient.Types.User do
  use Ash.TypedStruct

  typed_struct do
    field :name, :string
    field :email, :string, allow_nil?: true
    field :age, :integer
  end

  def adult?(%__MODULE__{age: age}), do: age >= 18

  def initials(%__MODULE__{name: name}) do
    name
    |> String.split()
    |> Enum.map(&String.first/1)
    |> Enum.join()
  end
end
```

Usage:

```elixir
{:ok, user} = MyApp.Extractor
  |> Ash.ActionInput.for_action(:extract_user, %{text: "..."})
  |> Ash.run_action()

if MyApp.BamlClient.Types.User.adult?(user) do
  # Process adult user
end
```

### Using Embedded Resources

For more complex validation and lifecycle hooks, use Ash embedded resources:

```elixir
# Replace generated TypedStruct with embedded resource
defmodule MyApp.BamlClient.Types.User do
  use Ash.Resource,
    data_layer: :embedded

  attributes do
    attribute :name, :string, allow_nil?: false
    attribute :email, :string

    attribute :age, :integer do
      constraints min: 0, max: 150
    end
  end

  validations do
    validate present(:name)
    validate string_length(:name, min: 2)

    validate fn changeset, _ctx ->
      if email = Ash.Changeset.get_attribute(changeset, :email) do
        if String.contains?(email, "@") do
          :ok
        else
          {:error, field: :email, message: "Invalid email format"}
        end
      else
        :ok
      end
    end
  end

  calculations do
    calculate :adult?, :boolean, expr(age >= 18)

    calculate :initials, :string do
      calculation fn records, _ctx ->
        Enum.map(records, fn record ->
          record.name
          |> String.split()
          |> Enum.map(&String.first/1)
          |> Enum.join()
        end)
      end
    end
  end
end
```

## Edge Cases and Limitations

### Union Types

BAML union types require manual mapping to Ash `:union` type:

**BAML:**
```baml
function SelectTool(msg: string) -> WeatherTool | CalculatorTool | SearchTool {
  // ...
}
```

**Ash Resource:**
```elixir
action :select_tool, :union do
  argument :msg, :string

  constraints [
    types: [
      weather_tool: [
        type: :struct,
        constraints: [instance_of: MyApp.BamlClient.Types.WeatherTool]
      ],
      calculator_tool: [
        type: :struct,
        constraints: [instance_of: MyApp.BamlClient.Types.CalculatorTool]
      ],
      search_tool: [
        type: :struct,
        constraints: [instance_of: MyApp.BamlClient.Types.SearchTool]
      ]
    ]
  ]

  run call_baml(:SelectTool)
end
```

See [Tool Calling Tutorial](../tutorials/03-tool-calling.md) for details.

### Recursive Types

BAML recursive types are supported but may need manual adjustment:

**BAML:**
```baml
class TreeNode {
  value string
  children TreeNode[]?
}
```

**Generated (may need @opaque):**
```elixir
defmodule MyApp.BamlClient.Types.TreeNode do
  use Ash.TypedStruct

  @type t :: %__MODULE__{
    value: String.t(),
    children: [t()] | nil
  }

  typed_struct do
    field :value, :string
    field :children, {:array, __MODULE__}, allow_nil?: true
  end
end
```

### Large Schemas

For projects with many BAML classes:

1. **Selective Generation**: Generate only types you need
2. **Module Organization**: Use subdirectories for namespacing
3. **Incremental Updates**: Regenerate when BAML schema changes

## Type Safety in Action

The type generator enables end-to-end type safety:

**BAML Schema:**
```baml
class Task {
  title string
  priority Priority  // Enum
  assignee User?     // Optional nested class
}

function ExtractTask(text: string) -> Task { ... }
```

**Generated Types:**
- `MyApp.BamlClient.Types.Priority` (enum)
- `MyApp.BamlClient.Types.User` (struct)
- `MyApp.BamlClient.Types.Task` (struct)

**Usage (fully typed):**
```elixir
{:ok, task} = MyApp.Extractor
  |> Ash.ActionInput.for_action(:extract_task, %{text: "..."})
  |> Ash.run_action()

# All fields are type-checked
task.title               # String.t()
task.priority            # :low | :medium | :high | :urgent
task.assignee            # MyApp.BamlClient.Types.User.t() | nil
task.assignee.name       # Compile error if assignee is nil!

# Pattern matching is safe
case task do
  %MyApp.BamlClient.Types.Task{priority: :urgent, assignee: nil} ->
    {:error, "Urgent tasks need assignee"}

  %MyApp.BamlClient.Types.Task{assignee: %{email: email}} when not is_nil(email) ->
    notify_assignee(email)

  _ ->
    :ok
end
```

## Regenerating Types

After updating BAML schemas, regenerate types:

```bash
# 1. Update BAML schema
vim baml_src/functions.baml

# 2. Regenerate Ash types
mix ash_baml.gen.types MyApp.BamlClient

# 3. Verify compilation
mix compile
```

**Tip**: Add to your CI/CD pipeline:

```yaml
# .github/workflows/ci.yml
- name: Check generated types are up to date
  run: |
    mix ash_baml.gen.types MyApp.BamlClient
    git diff --exit-code lib/my_app/baml_client/types/
```

## Next Steps

- **Tutorial**: [Structured Output](../tutorials/02-structured-output.md) - See type generation in action
- **Topic**: [Actions](actions.md) - Use generated types in actions
- **How-to**: [Call BAML Function](../how-to/call-baml-function.md) - Working with typed BAML functions

## Reference

- Module: `AshBaml.TypeGenerator` - Type generation API
- Module: `AshBaml.BamlParser` - BAML schema parsing
- Module: `AshBaml.CodeWriter` - Code generation utilities
- Task: `mix ash_baml.gen.types` - CLI task documentation
