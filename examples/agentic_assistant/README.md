# Agentic Assistant Example

This example demonstrates how to create **reusable agentic loops** that can be shared across different agent resources, each with their own state and context.

## The Pattern

The key insight is that the loop logic can be **decoupled from the resource**. This allows you to:

1. **Define the loop once** in a reusable action implementation
2. **Use it with any resource** that implements the required interface
3. **Each resource provides its own context** (customer info, user preferences, etc.)
4. **Each resource defines its own tools** specific to its domain

## Files in This Example

- `agent_loop.ex` - Reusable action implementation for agentic loops
- `customer_support_agent.ex` - Support agent with customer context
- `shopping_assistant.ex` - Shopping agent with cart and preferences
- `baml_functions.baml` - BAML function definitions for both agents

## How It Works

### 1. The Interface Contract

Any resource using the `AgentLoop` action must implement:

```elixir
# Decision action - returns union of tool calls or done signal
action :decide_next_action, :union do
  argument :message, :string
  argument :history, {:array, :map}

  constraints [
    types: [
      done: [type: :map],
      # ... your tool types ...
    ]
  ]
end

# Tool execution actions - one per tool type
action :execute_search_order, :map do
  argument :order_id, :string
  # ...
end
```

### 2. The Reusable Loop

```elixir
# In agent_loop.ex
def run(input, opts, _context) do
  loop(input.resource, message, history, max_iterations)
end

defp loop(resource, message, history, iterations) do
  # 1. Decide next action
  {:ok, decision} = Ash.run_action(resource, :decide_next_action, %{...})

  # 2. Execute tool
  {:ok, result} = Ash.run_action(resource, :execute_tool, %{...})

  # 3. Continue loop
  loop(resource, new_message, new_history, iterations - 1)
end
```

### 3. Resource-Specific Context

Each resource automatically provides its own context:

```elixir
# Customer Support Agent
attributes do
  attribute :customer_id, :string
  attribute :support_tier, :string
end

# Shopping Assistant
attributes do
  attribute :user_id, :string
  attribute :cart_items, {:array, :map}
  attribute :budget, :decimal
end
```

When tools execute, they have access to the resource's state:

```elixir
action :execute_search_order, :map do
  run fn input, _ctx ->
    # Access resource state
    customer_id = input.resource.customer_id
    order = Orders.find_by_customer(customer_id, input.arguments.order_id)
    {:ok, order}
  end
end
```

## Running the Example

### 1. Define BAML Functions

See `baml_functions.baml` for the function definitions.

### 2. Generate Types

```bash
mix ash_baml.gen.types MyApp.BamlClient
```

### 3. Use the Agents

```elixir
# Customer Support Agent
support_agent = %MyApp.CustomerSupportAgent{
  customer_id: "CUST123",
  support_tier: "premium"
}

{:ok, result} = support_agent
|> Ash.ActionInput.for_action(:handle_conversation, %{
  message: "I need help with my order #12345",
  max_turns: 10
})
|> Ash.run_action()

# Shopping Assistant
shopping_agent = %MyApp.ShoppingAssistant{
  user_id: "USER456",
  cart_items: [],
  budget: Decimal.new("100.00")
}

{:ok, result} = shopping_agent
|> Ash.ActionInput.for_action(:handle_conversation, %{
  message: "Help me find a gift under $50",
  max_turns: 8
})
|> Ash.run_action()
```

## Key Benefits

✅ **Reusability** - Write the loop logic once, use everywhere
✅ **Type Safety** - Compile-time validation via Ash and BAML
✅ **Testability** - Test each action independently
✅ **Context Isolation** - Each agent has its own state
✅ **Flexibility** - Easy to add new agents or modify existing ones

## Architecture

```
┌─────────────────────────────────────┐
│      AgentLoop (Reusable)           │
│  - Decide → Execute → Continue      │
└────────────┬────────────────────────┘
             │ uses interface
    ┌────────┴────────┐
    │                 │
┌───▼────────────┐ ┌─▼──────────────────┐
│  Support Agent │ │ Shopping Assistant │
│                │ │                    │
│ State:         │ │ State:             │
│ - customer_id  │ │ - user_id          │
│ - support_tier │ │ - cart_items       │
│                │ │ - budget           │
│ Tools:         │ │ Tools:             │
│ - search_order │ │ - search_products  │
│ - create_ticket│ │ - add_to_cart      │
│ - escalate     │ │ - checkout         │
└────────────────┘ └────────────────────┘
```

## Extending the Pattern

### Add a New Agent

1. Create a new resource
2. Define its specific attributes (state)
3. Implement the interface (decide + execute actions)
4. Add the `handle_conversation` action using `AgentLoop`

### Add New Tools

1. Add tool type to BAML function
2. Generate types
3. Add execution action to your resource
4. The loop automatically handles it!

### Customize Loop Behavior

You can create specialized loops by extending the base implementation:

```elixir
defmodule MyApp.Actions.AgentLoopWithMemory do
  use MyApp.Actions.AgentLoop

  # Override to add persistent memory
  defp loop(resource, message, history, iterations) do
    # Load previous conversations from database
    prior_context = load_conversation_history(resource)
    enhanced_history = prior_context ++ history

    super(resource, message, enhanced_history, iterations)
  end
end
```

## Production Considerations

### Error Handling

The loop should handle errors gracefully:

```elixir
case Ash.run_action(resource, action, params) do
  {:ok, result} ->
    {:continue, result}

  {:error, %Ash.Error.Invalid{} = error} ->
    # Validation error - retry with clarification
    {:retry, format_validation_error(error)}

  {:error, error} ->
    # Fatal error - stop loop
    {:error, error}
end
```

### Rate Limiting

Add rate limiting to prevent runaway costs:

```elixir
defp loop(resource, message, history, iterations, opts) do
  # Track token usage
  total_tokens = calculate_tokens(history)
  max_tokens = opts[:max_tokens] || 10_000

  if total_tokens > max_tokens do
    {:ok, %{history: history, stopped_reason: :token_limit}}
  else
    # Continue loop
  end
end
```

### Streaming

For real-time feedback, use streaming actions:

```elixir
action :handle_conversation_stream, :stream do
  argument :message, :string

  run fn input, _ctx ->
    stream = Stream.resource(
      fn -> {input.resource, input.arguments.message, [], 5} end,
      fn state -> iterate_and_stream(state) end,
      fn _state -> :ok end
    )

    {:ok, stream}
  end
end
```

## See Also

- [Agentic Loop Patterns Guide](../agentic_loop_patterns.md) - Comprehensive guide to all approaches
- [BAML Function Calling Docs](https://docs.boundaryml.com/examples/prompt-engineering/tools-function-calling)
- [Ash Reactor Documentation](https://hexdocs.pm/ash/reactor.html)
