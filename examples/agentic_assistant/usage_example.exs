#!/usr/bin/env elixir

# Usage examples for the agentic assistant pattern
#
# Run this file with: elixir examples/agentic_assistant/usage_example.exs

IO.puts("""
================================================================================
Agentic Assistant Examples
================================================================================

This demonstrates how the SAME agentic loop can be used with DIFFERENT agents,
each with their own state, context, and tools.

""")

# ============================================================
# Example 1: Customer Support Agent
# ============================================================

IO.puts("""
Example 1: Customer Support Agent
----------------------------------
""")

# Create a support agent with customer-specific context
support_agent = %AshBaml.Examples.CustomerSupportAgent{
  customer_id: "CUST-12345",
  support_tier: "premium",
  agent_name: "Alice",
  available_hours: "24/7"
}

IO.puts("Agent created:")
IO.inspect(support_agent, label: "Support Agent")

# Start a conversation
IO.puts("\n💬 Customer: \"I need help with my order #ORD-12345\"\n")

{:ok, result} =
  support_agent
  |> Ash.ActionInput.for_action(:handle_conversation, %{
    message: "I need help with my order #ORD-12345",
    max_turns: 10
  })
  |> Ash.run_action()

IO.puts("Conversation completed!")
IO.inspect(result, label: "Result", pretty: true)

IO.puts("""

What happened:
1. Agent received the message with customer context (ID, tier, etc.)
2. AgentLoop decided to lookup the order
3. Order details were retrieved using customer_id from resource state
4. Agent decided the task was complete
5. Loop terminated with conversation history

""")

# ============================================================
# Example 2: Shopping Assistant
# ============================================================

IO.puts("""

Example 2: Shopping Assistant
------------------------------
""")

# Create a shopping assistant with shopping-specific context
shopping_agent = %AshBaml.Examples.ShoppingAssistant{
  user_id: "USER-67890",
  cart_items: [],
  budget: Decimal.new("100.00"),
  preferences: %{
    keywords: ["blue", "widget"],
    preferred_brands: ["ProTech"]
  },
  session_id: "SESSION-ABC123"
}

IO.puts("Agent created:")
IO.inspect(shopping_agent, label: "Shopping Agent")

# Start a shopping conversation
IO.puts("\n💬 User: \"I'm looking for a gift under $50\"\n")

{:ok, result} =
  shopping_agent
  |> Ash.ActionInput.for_action(:handle_conversation, %{
    message: "I'm looking for a gift under $50",
    max_turns: 8
  })
  |> Ash.run_action()

IO.puts("Shopping session completed!")
IO.inspect(result, label: "Result", pretty: true)

IO.puts("""

What happened:
1. Agent received the message with shopping context (budget, preferences, etc.)
2. AgentLoop decided to search for products
3. Products were filtered by budget from resource state
4. Agent decided to add a product to cart
5. Cart was updated (in production, would persist)
6. Agent decided task was complete
7. Loop terminated with shopping history

""")

# ============================================================
# Key Observations
# ============================================================

IO.puts("""

================================================================================
Key Observations
================================================================================

🔄 SAME LOOP, DIFFERENT AGENTS

Both agents used `AshBaml.Examples.AgentLoop` - the EXACT same code!

The loop doesn't care about:
- What domain you're in (support vs shopping)
- What tools are available
- What state the resource has

The loop ONLY cares that the resource implements:
- :decide_next_action (returns a union)
- :execute_{tool_type} (one per tool)

📦 RESOURCE STATE PROVIDES CONTEXT

Each resource's attributes automatically provide context:

Support Agent State:
  - customer_id, support_tier, agent_name
  - Used when looking up orders, creating tickets

Shopping Agent State:
  - user_id, cart_items, budget, preferences
  - Used when searching products, managing cart

The tools access this state via `input.resource.*`

🔧 DOMAIN-SPECIFIC TOOLS

Each agent has completely different tools:

Support Tools:
  - lookup_order
  - create_ticket
  - escalate_to_human

Shopping Tools:
  - search_products
  - add_to_cart
  - checkout

The loop dynamically calls `:execute_{tool_type}` based on
what the LLM decides!

🎯 BENEFITS

✅ Write loop logic once, reuse everywhere
✅ Each agent is isolated and testable
✅ Easy to add new agents (just implement the interface)
✅ Type-safe via Ash and BAML
✅ Resource state automatically available to tools

================================================================================
""")

# ============================================================
# Extending the Pattern
# ============================================================

IO.puts("""

Want to add a new agent?
------------------------

1. Create a new resource:

    defmodule MyApp.ResearchAgent do
      use Ash.Resource, extensions: [AshBaml.Resource]

      # Your domain-specific state
      attributes do
        attribute :research_topic, :string
        attribute :depth, :string
        attribute :sources, {:array, :string}
      end

2. Implement the interface:

    actions do
      action :decide_next_action, :union do
        # Your tool types
        constraints [
          types: [
            done: [type: :map],
            search_papers: [...],
            summarize: [...],
          ]
        ]
      end

      action :execute_search_papers, :map do
        # Use resource state: input.resource.research_topic
      end

      action :execute_summarize, :map do
        # ...
      end

3. Add the loop action:

    action :conduct_research, :map do
      argument :message, :string
      argument :max_turns, :integer, default: 10

      run AshBaml.Examples.AgentLoop  # That's it!
    end

Done! You now have a research agent using the same loop pattern.

================================================================================
""")
