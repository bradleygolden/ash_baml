defmodule AshBaml.Examples.CustomerSupportAgent do
  @moduledoc """
  An example customer support agent that uses the reusable AgentLoop.

  This agent has customer-specific context and provides tools for:
  - Looking up orders
  - Creating support tickets
  - Escalating to human agents

  The agent uses the same loop logic as other agents but provides
  its own context and tools specific to customer support.
  """

  use Ash.Resource,
    domain: AshBaml.Examples.Domain,
    extensions: [AshBaml.Resource]

  # Agent-specific state
  attributes do
    attribute :customer_id, :string do
      allow_nil? false
      description "The customer this agent is helping"
    end

    attribute :support_tier, :string do
      default "standard"
      description "Customer support tier (standard, premium, enterprise)"
    end

    attribute :agent_name, :string do
      default "Support Bot"
      description "Name shown to the customer"
    end

    attribute :available_hours, :string do
      default "24/7"
      description "When human support is available"
    end
  end

  # Configure BAML client
  baml do
    # In a real app, this would be your actual BAML client
    client_module AshBaml.Examples.BamlClient
  end

  actions do
    # Default actions
    defaults [:read, :destroy]

    create :new do
      accept [:customer_id, :support_tier, :agent_name, :available_hours]
    end

    # ============================================================
    # REQUIRED INTERFACE FOR AgentLoop
    # ============================================================

    # Decision action - LLM decides what to do next
    action :decide_next_action, :union do
      argument :message, :string, allow_nil?: false
      argument :history, {:array, :map}, default: []

      constraints [
        types: [
          # Signal completion
          done: [
            type: :map,
            description: "Conversation is complete"
          ],

          # Available tools
          lookup_order: [
            type: :struct,
            constraints: [instance_of: AshBaml.Examples.BamlClient.Types.LookupOrder],
            description: "Look up an order by ID"
          ],
          create_ticket: [
            type: :struct,
            constraints: [instance_of: AshBaml.Examples.BamlClient.Types.CreateTicket],
            description: "Create a support ticket"
          ],
          escalate_to_human: [
            type: :struct,
            constraints: [instance_of: AshBaml.Examples.BamlClient.Types.EscalateToHuman],
            description: "Escalate to a human agent"
          ]
        ]
      ]

      # Implementation: Call BAML with enhanced context
      run fn input, _context ->
        # Enhance the message with customer context
        enhanced_message = build_context_message(input)

        # Call BAML function (would be real in production)
        # For now, return a mock decision
        mock_decision(input.arguments.message, input.arguments.history)
      end
    end

    # Tool execution actions
    action :execute_lookup_order, :map do
      argument :order_id, :string, allow_nil?: false

      run fn input, _context ->
        # Access resource state
        customer_id = input.resource.customer_id

        # In production, this would query your orders database
        order = %{
          order_id: input.arguments.order_id,
          customer_id: customer_id,
          status: "shipped",
          tracking_number: "1Z999AA10123456784",
          items: ["Blue Widget", "Red Gadget"],
          total: "$49.99",
          shipped_date: "2025-10-28"
        }

        {:ok, order}
      end
    end

    action :execute_create_ticket, :map do
      argument :issue, :string, allow_nil?: false
      argument :priority, :string, default: "normal"
      argument :category, :string, allow_nil?: false

      run fn input, _context ->
        customer_id = input.resource.customer_id
        support_tier = input.resource.support_tier

        # In production, create ticket in your system
        ticket = %{
          ticket_id: "TKT-#{:rand.uniform(99999)}",
          customer_id: customer_id,
          issue: input.arguments.issue,
          priority: determine_priority(input.arguments.priority, support_tier),
          category: input.arguments.category,
          status: "open",
          created_at: DateTime.utc_now()
        }

        {:ok, ticket}
      end
    end

    action :execute_escalate_to_human, :map do
      argument :reason, :string, allow_nil?: false
      argument :urgency, :string, default: "normal"

      run fn input, _context ->
        customer_id = input.resource.customer_id
        support_tier = input.resource.support_tier
        available_hours = input.resource.available_hours

        # In production, route to human agent
        escalation = %{
          escalation_id: "ESC-#{:rand.uniform(99999)}",
          customer_id: customer_id,
          reason: input.arguments.reason,
          urgency: input.arguments.urgency,
          support_tier: support_tier,
          estimated_wait: estimate_wait_time(support_tier),
          available_hours: available_hours,
          status: "queued"
        }

        {:ok, escalation}
      end
    end

    # ============================================================
    # MAIN AGENT ACTION - Uses the reusable AgentLoop
    # ============================================================

    action :handle_conversation, :map do
      argument :message, :string, allow_nil?: false
      argument :max_turns, :integer, default: 10
      argument :conversation_history, {:array, :map}, default: []

      description """
      Handle a customer support conversation using the agentic loop.

      The agent will:
      1. Understand the customer's request
      2. Decide which tools to use (lookup order, create ticket, escalate)
      3. Execute tools with customer-specific context
      4. Continue until the issue is resolved or escalated
      """

      # Use the reusable loop implementation!
      run AshBaml.Examples.AgentLoop
    end
  end

  # ============================================================
  # HELPER FUNCTIONS
  # ============================================================

  defp build_context_message(input) do
    """
    You are #{input.resource.agent_name}, a customer support agent.

    Customer Context:
    - Customer ID: #{input.resource.customer_id}
    - Support Tier: #{input.resource.support_tier}
    - Available Hours: #{input.resource.available_hours}

    Conversation History:
    #{format_history(input.arguments.history)}

    Current Message:
    #{input.arguments.message}

    Available Actions:
    1. lookup_order - Look up order information
    2. create_ticket - Create a support ticket
    3. escalate_to_human - Escalate to a human agent
    4. done - Complete the conversation

    Decide what to do next to help this customer.
    """
  end

  defp format_history([]), do: "(No previous interactions)"

  defp format_history(history) do
    history
    |> Enum.take(5)
    |> Enum.map(fn item ->
      """
      - Tool: #{item[:tool]}
        Result: #{inspect(item[:result])}
      """
    end)
    |> Enum.join("\n")
  end

  defp determine_priority(requested_priority, support_tier) do
    case {requested_priority, support_tier} do
      {_, "enterprise"} -> "high"
      {"urgent", "premium"} -> "high"
      {"urgent", _} -> "normal"
      {priority, _} -> priority
    end
  end

  defp estimate_wait_time("enterprise"), do: "< 5 minutes"
  defp estimate_wait_time("premium"), do: "< 15 minutes"
  defp estimate_wait_time(_), do: "< 30 minutes"

  # Mock decision for demonstration (replace with real BAML call)
  defp mock_decision(message, history) do
    cond do
      String.contains?(String.downcase(message), "order") && length(history) == 0 ->
        # First message about an order - look it up
        {:ok,
         %Ash.Union{
           type: :lookup_order,
           value: %AshBaml.Examples.BamlClient.Types.LookupOrder{
             order_id: "ORD-12345"
           }
         }}

      length(history) >= 1 ->
        # After one interaction, mark as done
        {:ok,
         %Ash.Union{
           type: :done,
           value: %{
             response: "I've looked up your order. Is there anything else I can help with?",
             satisfied: true
           }
         }}

      true ->
        # Create a ticket
        {:ok,
         %Ash.Union{
           type: :create_ticket,
           value: %AshBaml.Examples.BamlClient.Types.CreateTicket{
             issue: message,
             priority: "normal",
             category: "general"
           }
         }}
    end
  end
end
