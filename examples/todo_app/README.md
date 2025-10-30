# Todo App Example

This is a toy example demonstrating how to use `ash_baml` with Ash Framework to generate types from BAML schemas.

## What This Example Demonstrates

1. **BAML Schema Definition** - Define types using BAML for LLM interactions
2. **Type Generation** - Generate Ash-compatible types from BAML schemas
3. **Ash Integration** - Use generated types in Ash resources for type-safe development

## Project Structure

```
todo_app/
├── baml_src/               # BAML schema files
│   ├── types.baml          # Type definitions (enums and classes)
│   └── functions.baml      # LLM function definitions
├── lib/
│   ├── todo_app/
│   │   ├── baml_client.ex              # BAML client module
│   │   ├── baml_client/
│   │   │   └── types/                  # Generated types (auto-generated)
│   │   │       ├── task.ex             # Task struct
│   │   │       ├── priority.ex         # Priority enum
│   │   │       ├── status.ex           # Status enum
│   │   │       └── task_category.ex    # TaskCategory enum
│   │   ├── domain.ex                   # Ash domain
│   │   └── task.ex                     # Ash resource using generated types
```

## Getting Started

### 1. Install Dependencies

```bash
mix deps.get
```

### 2. View the BAML Schema

Check out `baml_src/types.baml` to see the type definitions:

```baml
enum Priority {
  Low
  Medium
  High
  Urgent
}

class Task {
  title string
  description string?
  priority Priority
  status Status
  // ... more fields
}
```

### 3. Generate Types from BAML Schema

Run the type generator to create Ash-compatible types:

```bash
mix ash_baml.gen.types TodoApp.BamlClient --verbose
```

This will generate:
- `lib/todo_app/baml_client/types/task.ex` - TypedStruct for Task class
- `lib/todo_app/baml_client/types/priority.ex` - Enum for Priority
- `lib/todo_app/baml_client/types/status.ex` - Enum for Status
- `lib/todo_app/baml_client/types/task_category.ex` - Enum for TaskCategory

### 4. View Generated Types

Example generated enum (`lib/todo_app/baml_client/types/priority.ex`):

```elixir
defmodule TodoApp.BamlClient.Types.Priority do
  use Ash.Type.Enum, values: [:low, :medium, :high, :urgent]

  @moduledoc """
  Generated from BAML enum: Priority
  ...
  """
end
```

Example generated struct (`lib/todo_app/baml_client/types/task.ex`):

```elixir
defmodule TodoApp.BamlClient.Types.Task do
  use Ash.TypedStruct

  typed_struct do
    field(:title, :string, allow_nil?: false)
    field(:priority, TodoApp.BamlClient.Types.Priority, allow_nil?: false)
    field(:status, TodoApp.BamlClient.Types.Status, allow_nil?: false)
    # ... more fields
  end
end
```

### 5. Use Generated Types in Ash Resources

See `lib/todo_app/task.ex` for how the generated types are used:

```elixir
defmodule TodoApp.Task do
  use Ash.Resource,
    domain: TodoApp.Domain,
    data_layer: Ash.DataLayer.Ets

  alias TodoApp.BamlClient.Types.{Priority, Status, TaskCategory}

  attributes do
    uuid_primary_key :id

    # Using BAML-generated enum types
    attribute :priority, Priority do
      allow_nil? false
      default :medium
      public? true
    end

    attribute :status, Status do
      allow_nil? false
      default :todo
      public? true
    end

    # ... more attributes
  end
end
```

### 6. Compile the Project

```bash
mix compile
```

Everything should compile successfully with full type safety!

## Key Features Demonstrated

### Automatic Type References

The type generator automatically creates fully-qualified module references for BAML types:

- **Before fix**: Generated `field(:priority, :Priority, ...)` (would fail)
- **After fix**: Generated `field(:priority, TodoApp.BamlClient.Types.Priority, ...)` (works!)

### Type Safety

The generated types provide:
- **Compile-time checking** - Invalid enum values caught at compile time
- **IDE autocomplete** - Full autocomplete for all fields and values
- **Type specifications** - Clear type information for Dialyzer
- **Documentation** - Auto-generated docs from BAML schemas

### Regeneration Workflow

When you update your BAML schema:

1. Edit `baml_src/types.baml` or `baml_src/functions.baml`
2. Run `mix ash_baml.gen.types TodoApp.BamlClient`
3. Generated types are updated automatically
4. Compiler catches any breaking changes

## Type Mapping

BAML types are mapped to Elixir/Ash types as follows:

| BAML Type | Generated Type |
|-----------|----------------|
| `string` | `:string` |
| `int` | `:integer` |
| `float` | `:float` |
| `bool` | `:boolean` |
| `string[]` | `{:array, :string}` |
| `MyEnum` | `MyApp.BamlClient.Types.MyEnum` (full module name) |
| `MyClass` | `MyApp.BamlClient.Types.MyClass` (full module name) |
| `field?` | `allow_nil?: true` |

## Known Limitations

1. **Nested Structs in Arrays**: Arrays of BAML classes (e.g., `Task[]`) are not yet fully supported in Ash.TypedStruct
2. **Inline Union Types**: BAML inline unions like `"add" | "subtract"` currently map to `:any`

## Example Usage

Here's how you might use the Task resource in IEx:

```elixir
# Start IEx
iex -S mix

# Create a task
{:ok, task} = TodoApp.Task.create(%{
  title: "Buy groceries",
  description: "Milk, bread, eggs",
  priority: :high,
  status: :todo,
  category: :shopping,
  tags: ["urgent", "food"]
})

# Update task status
{:ok, updated_task} = TodoApp.Task.change_status(task, %{status: :done})

# List all tasks
tasks = TodoApp.Task.list!()
```

## Next Steps

This example demonstrates the basics. In a real application, you would:

1. Add database persistence (replace `Ash.DataLayer.Ets` with `AshPostgres.DataLayer`)
2. Implement the BAML functions to call actual LLMs
3. Create actions that use BAML to parse natural language into tasks
4. Add more complex validations and business logic

## Learning More

- **BAML Documentation**: https://docs.boundaryml.com/
- **Ash Framework**: https://hexdocs.pm/ash/
- **ash_baml README**: ../../README.md

## Troubleshooting

### Types not found after generation

Make sure to recompile after generating types:
```bash
mix clean && mix compile
```

### BAML client module not found

Ensure your `BamlClient` module includes the `__baml_src_path__/0` function. For projects using the Hex version of `baml_elixir`, add it manually:

```elixir
def __baml_src_path__ do
  Path.join(File.cwd!(), "baml_src")
end
```

### Compilation errors with generated types

Re-run the type generator to ensure types are in sync:
```bash
rm -rf lib/your_app/baml_client/types
mix ash_baml.gen.types YourApp.BamlClient
```
