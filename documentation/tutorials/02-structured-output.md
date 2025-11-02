# Structured Output with Complex Types

Learn how to work with complex BAML types including nested structures, arrays, optional fields, and enums in your Ash resources.

## Prerequisites

- Completed [Get Started](01-get-started.md) tutorial
- Understanding of Ash TypedStruct
- Familiarity with BAML class syntax

## Goals

1. Define complex BAML classes with nested structures
2. Work with arrays and optional fields
3. Use enums for constrained values
4. Generate and use complex Ash types

## Define a Complex BAML Schema

Let's build a task extraction system that returns structured task data.

Create `baml_src/task_schema.baml`:

```baml
enum Priority {
  Low
  Medium
  High
  Urgent
}

enum Status {
  Todo
  InProgress
  Done
}

class Assignee {
  name string
  email string?
}

class Task {
  title string @description("Brief task title")
  description string? @description("Detailed description")
  priority Priority @description("Task priority level")
  status Status @description("Current status")
  assignee Assignee? @description("Optional assignee")
  tags string[] @description("Task tags")
  due_date string? @description("Due date in ISO format")
}

class TaskList {
  tasks Task[]
  total_count int
  extracted_from string
}

function ExtractTasks(input: string) -> TaskList {
  client GPT4
  prompt #"
    Extract all tasks from the following text.
    For each task, identify:
    - Title (required)
    - Description (if available)
    - Priority (default to Medium if not specified)
    - Status (default to Todo)
    - Assignee (if mentioned)
    - Tags (relevant keywords)
    - Due date (if mentioned)

    Text: {{ input }}

    {{ ctx.output_format }}
  "#
}
```

## Generate Ash Types

Run the type generator:

```bash
mix ash_baml.gen.types MyApp.BamlClient
```

This creates several type modules:

**`lib/my_app/baml_client/types/priority.ex`:**
```elixir
defmodule MyApp.BamlClient.Types.Priority do
  use Ash.Type.Enum,
    values: [:low, :medium, :high, :urgent]
end
```

**`lib/my_app/baml_client/types/assignee.ex`:**
```elixir
defmodule MyApp.BamlClient.Types.Assignee do
  use Ash.TypedStruct

  typed_struct do
    field :name, :string
    field :email, :string, allow_nil?: true
  end
end
```

**`lib/my_app/baml_client/types/task.ex`:**
```elixir
defmodule MyApp.BamlClient.Types.Task do
  use Ash.TypedStruct

  typed_struct do
    field :title, :string
    field :description, :string, allow_nil?: true
    field :priority, MyApp.BamlClient.Types.Priority
    field :status, MyApp.BamlClient.Types.Status
    field :assignee, MyApp.BamlClient.Types.Assignee, allow_nil?: true
    field :tags, {:array, :string}
    field :due_date, :string, allow_nil?: true
  end
end
```

**`lib/my_app/baml_client/types/task_list.ex`:**
```elixir
defmodule MyApp.BamlClient.Types.TaskList do
  use Ash.TypedStruct

  typed_struct do
    field :tasks, {:array, MyApp.BamlClient.Types.Task}
    field :total_count, :integer
    field :extracted_from, :string
  end
end
```

## Create the Ash Resource

Create `lib/my_app/task_extractor.ex`:

```elixir
defmodule MyApp.TaskExtractor do
  use Ash.Resource,
    domain: MyApp.Domain,
    extensions: [AshBaml.Resource]

  baml do
    client :default
    import_functions [:ExtractTasks]
  end

  # Auto-generated actions:
  # - :extract_tasks (returns TaskList)
  # - :extract_tasks_stream (returns Stream of TaskList)
end
```

Add to your domain:

```elixir
defmodule MyApp.Domain do
  use Ash.Domain

  resources do
    resource MyApp.Assistant
    resource MyApp.TaskExtractor  # Add this
  end
end
```

## Use the Complex Types

Start IEx and extract tasks from natural language:

```elixir
iex> input = """
...> Project tasks:
...> - HIGH: Fix authentication bug (assign to alice@example.com, due Friday)
...> - Implement user dashboard #frontend #ui
...> - URGENT: Deploy hotfix for payment issue (Bob)
...> - Write API documentation #docs
...> """

iex> {:ok, result} = MyApp.TaskExtractor
...>   |> Ash.ActionInput.for_action(:extract_tasks, %{input: input})
...>   |> Ash.run_action()

iex> result
%MyApp.BamlClient.Types.TaskList{
  tasks: [
    %MyApp.BamlClient.Types.Task{
      title: "Fix authentication bug",
      description: nil,
      priority: :high,
      status: :todo,
      assignee: %MyApp.BamlClient.Types.Assignee{
        name: "Alice",
        email: "alice@example.com"
      },
      tags: [],
      due_date: "2025-11-01"
    },
    %MyApp.BamlClient.Types.Task{
      title: "Implement user dashboard",
      description: nil,
      priority: :medium,
      status: :todo,
      assignee: nil,
      tags: ["frontend", "ui"],
      due_date: nil
    },
    # ... more tasks
  ],
  total_count: 4,
  extracted_from: "Project tasks: ..."
}
```

## Working with Nested Data

Access nested fields naturally:

```elixir
# Get all high priority tasks
high_priority_tasks =
  result.tasks
  |> Enum.filter(&(&1.priority == :high))

# Get tasks with assignees
assigned_tasks =
  result.tasks
  |> Enum.filter(&(&1.assignee != nil))
  |> Enum.map(fn task ->
    {task.title, task.assignee.name}
  end)

# Get all unique tags
all_tags =
  result.tasks
  |> Enum.flat_map(&(&1.tags))
  |> Enum.uniq()
```

## Type Mapping Reference

| BAML Type | Ash Type | Notes |
|-----------|----------|-------|
| `class Task { ... }` | `MyApp.BamlClient.Types.Task` | TypedStruct module |
| `enum Priority { ... }` | `Ash.Type.Enum` | Atom values (`:low`, `:medium`, etc.) |
| `string` | `:string` | Direct mapping |
| `string?` | `:string` with `allow_nil?: true` | Optional field |
| `string[]` | `{:array, :string}` | Array type |
| `Task[]` | `{:array, MyApp.BamlClient.Types.Task}` | Array of structs |

## Custom Validation

You can add custom validation to generated types:

```elixir
defmodule MyApp.BamlClient.Types.Task do
  use Ash.TypedStruct

  typed_struct do
    field :title, :string
    field :priority, MyApp.BamlClient.Types.Priority
    # ... other fields
  end

  # Add custom validation
  def validate(task) do
    cond do
      String.length(task.title) < 3 ->
        {:error, "Title must be at least 3 characters"}

      task.priority == :urgent and is_nil(task.assignee) ->
        {:error, "Urgent tasks must have an assignee"}

      true ->
        :ok
    end
  end
end
```

## Multiple Return Types

You can define multiple BAML functions with different return types in the same resource:

```baml
function ExtractTasks(input: string) -> TaskList { ... }
function SummarizeTasks(tasks: Task[]) -> string { ... }
function CategorizeTasks(input: string) -> Task[] { ... }
```

```elixir
defmodule MyApp.TaskExtractor do
  use Ash.Resource,
    domain: MyApp.Domain,
    extensions: [AshBaml.Resource]

  baml do
    client :default
    import_functions [:ExtractTasks, :SummarizeTasks, :CategorizeTasks]
  end

  # Auto-generates 6 actions:
  # :extract_tasks, :extract_tasks_stream
  # :summarize_tasks, :summarize_tasks_stream
  # :categorize_tasks, :categorize_tasks_stream
end
```

## What You Learned

- Defining complex BAML schemas with nested structures
- Using enums for constrained values
- Working with optional fields and arrays
- Generating multiple related Ash types
- Accessing nested data in returned structures
- Type mapping from BAML to Ash
- Adding custom validation to generated types

## Next Steps

- **Tutorial 3**: [Tool Calling](03-tool-calling.md) - Let the LLM select and invoke tools
- **Tutorial 4**: [Building an Agent](04-building-an-agent.md) - Create multi-step agentic workflows

See also:
- [Type Generation](../topics/type-generation.md) - Complete type mapping reference
- [How to Call BAML Functions](../how-to/call-baml-function.md) - Advanced usage patterns
