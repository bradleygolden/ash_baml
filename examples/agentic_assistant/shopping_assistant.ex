defmodule AshBaml.Examples.ShoppingAssistant do
  @moduledoc """
  An example shopping assistant that uses the same reusable AgentLoop.

  This agent has shopping-specific context and provides tools for:
  - Searching for products
  - Adding items to cart
  - Checking out

  Notice how this agent shares NO code with CustomerSupportAgent except
  for the AgentLoop implementation - yet both work seamlessly!
  """

  use Ash.Resource,
    domain: AshBaml.Examples.Domain,
    extensions: [AshBaml.Resource]

  # Agent-specific state (completely different from support agent!)
  attributes do
    attribute :user_id, :string do
      allow_nil? false
      description "The user this agent is helping"
    end

    attribute :cart_items, {:array, :map} do
      default []
      description "Current items in the shopping cart"
    end

    attribute :budget, :decimal do
      description "User's stated budget (optional)"
    end

    attribute :preferences, :map do
      default %{}
      description "User preferences (style, brands, etc.)"
    end

    attribute :session_id, :string do
      description "Shopping session ID"
    end
  end

  # Configure BAML client (same as support agent - or could be different!)
  baml do
    client_module AshBaml.Examples.BamlClient
  end

  actions do
    defaults [:read, :destroy]

    create :new do
      accept [:user_id, :cart_items, :budget, :preferences, :session_id]
    end

    # ============================================================
    # REQUIRED INTERFACE FOR AgentLoop (Different tools than support!)
    # ============================================================

    action :decide_next_action, :union do
      argument :message, :string, allow_nil?: false
      argument :history, {:array, :map}, default: []

      constraints [
        types: [
          # Signal completion
          done: [
            type: :map,
            description: "Shopping session is complete"
          ],

          # Shopping-specific tools
          search_products: [
            type: :struct,
            constraints: [instance_of: AshBaml.Examples.BamlClient.Types.SearchProducts],
            description: "Search for products"
          ],
          add_to_cart: [
            type: :struct,
            constraints: [instance_of: AshBaml.Examples.BamlClient.Types.AddToCart],
            description: "Add an item to the cart"
          ],
          remove_from_cart: [
            type: :struct,
            constraints: [instance_of: AshBaml.Examples.BamlClient.Types.RemoveFromCart],
            description: "Remove an item from the cart"
          ],
          checkout: [
            type: :struct,
            constraints: [instance_of: AshBaml.Examples.BamlClient.Types.Checkout],
            description: "Proceed to checkout"
          ]
        ]
      ]

      run fn input, _context ->
        # Enhance with shopping context
        enhanced_message = build_shopping_context(input)

        # Mock decision (replace with real BAML call)
        mock_shopping_decision(input.arguments.message, input.arguments.history)
      end
    end

    # Shopping tool implementations
    action :execute_search_products, :map do
      argument :query, :string, allow_nil?: false
      argument :category, :string
      argument :max_price, :decimal

      run fn input, _context ->
        # Access shopping-specific state
        budget = input.resource.budget
        preferences = input.resource.preferences

        # Filter by budget if provided
        effective_max_price =
          input.arguments.max_price ||
            budget ||
            Decimal.new("1000")

        # Mock product search
        products = [
          %{
            id: "PROD-001",
            name: "Blue Widget Pro",
            price: Decimal.new("29.99"),
            rating: 4.5,
            in_stock: true,
            matches_preferences: matches_preferences?("Blue Widget Pro", preferences)
          },
          %{
            id: "PROD-002",
            name: "Red Gadget Ultra",
            price: Decimal.new("49.99"),
            rating: 4.8,
            in_stock: true,
            matches_preferences: matches_preferences?("Red Gadget Ultra", preferences)
          }
        ]
        |> Enum.filter(fn p -> Decimal.compare(p.price, effective_max_price) != :gt end)

        {:ok, %{products: products, query: input.arguments.query}}
      end
    end

    action :execute_add_to_cart, :map do
      argument :product_id, :string, allow_nil?: false
      argument :quantity, :integer, default: 1

      run fn input, _context ->
        # Update cart (in production, this would update the resource)
        cart_item = %{
          product_id: input.arguments.product_id,
          quantity: input.arguments.quantity,
          added_at: DateTime.utc_now()
        }

        current_cart = input.resource.cart_items
        new_cart = [cart_item | current_cart]
        cart_total = calculate_cart_total(new_cart)

        {:ok,
         %{
           item_added: cart_item,
           cart_count: length(new_cart),
           cart_total: cart_total,
           within_budget: within_budget?(cart_total, input.resource.budget)
         }}
      end
    end

    action :execute_remove_from_cart, :map do
      argument :product_id, :string, allow_nil?: false

      run fn input, _context ->
        current_cart = input.resource.cart_items

        new_cart =
          Enum.reject(current_cart, fn item ->
            item.product_id == input.arguments.product_id
          end)

        {:ok,
         %{
           removed: input.arguments.product_id,
           cart_count: length(new_cart),
           cart_total: calculate_cart_total(new_cart)
         }}
      end
    end

    action :execute_checkout, :map do
      argument :payment_method, :string, default: "default"
      argument :shipping_address_id, :string

      run fn input, _context ->
        cart_items = input.resource.cart_items
        user_id = input.resource.user_id

        # Mock checkout
        order = %{
          order_id: "ORD-#{:rand.uniform(99999)}",
          user_id: user_id,
          items: cart_items,
          total: calculate_cart_total(cart_items),
          payment_method: input.arguments.payment_method,
          status: "confirmed",
          estimated_delivery: Date.add(Date.utc_today(), 3)
        }

        {:ok, order}
      end
    end

    # ============================================================
    # MAIN AGENT ACTION - Uses the SAME reusable AgentLoop!
    # ============================================================

    action :handle_conversation, :map do
      argument :message, :string, allow_nil?: false
      argument :max_turns, :integer, default: 8
      argument :conversation_history, {:array, :map}, default: []

      description """
      Handle a shopping conversation using the agentic loop.

      The agent will:
      1. Understand what the user wants to buy
      2. Search for relevant products
      3. Help add items to cart within budget
      4. Assist with checkout when ready
      """

      # Same reusable loop, different domain!
      run AshBaml.Examples.AgentLoop
    end
  end

  # ============================================================
  # HELPER FUNCTIONS
  # ============================================================

  defp build_shopping_context(input) do
    """
    You are a shopping assistant helping a customer find products.

    Shopping Context:
    - User ID: #{input.resource.user_id}
    - Budget: #{format_budget(input.resource.budget)}
    - Cart Items: #{length(input.resource.cart_items)}
    - Cart Total: #{calculate_cart_total(input.resource.cart_items)}
    - Preferences: #{inspect(input.resource.preferences)}

    Conversation History:
    #{format_shopping_history(input.arguments.history)}

    Current Message:
    #{input.arguments.message}

    Available Actions:
    1. search_products - Find products matching criteria
    2. add_to_cart - Add a product to the cart
    3. remove_from_cart - Remove a product from the cart
    4. checkout - Complete the purchase
    5. done - End the shopping session

    Help the user find what they need within their budget.
    """
  end

  defp format_budget(nil), do: "Not specified"
  defp format_budget(budget), do: "$#{Decimal.to_string(budget)}"

  defp format_shopping_history([]), do: "(No previous interactions)"

  defp format_shopping_history(history) do
    history
    |> Enum.take(5)
    |> Enum.map(fn item ->
      """
      - Action: #{item[:tool]}
        Result: #{inspect(item[:result])}
      """
    end)
    |> Enum.join("\n")
  end

  defp matches_preferences?(_product_name, preferences) when preferences == %{}, do: false

  defp matches_preferences?(product_name, preferences) do
    # Simple matching logic
    preferred_terms = Map.get(preferences, :keywords, [])
    Enum.any?(preferred_terms, &String.contains?(String.downcase(product_name), &1))
  end

  defp calculate_cart_total(cart_items) do
    # Mock calculation
    Decimal.mult(Decimal.new(length(cart_items)), Decimal.new("29.99"))
  end

  defp within_budget?(_total, nil), do: true

  defp within_budget?(total, budget) do
    Decimal.compare(total, budget) != :gt
  end

  defp mock_shopping_decision(message, history) do
    cond do
      String.contains?(String.downcase(message), ["find", "search", "looking for"]) &&
          length(history) == 0 ->
        # First message is a search
        {:ok,
         %Ash.Union{
           type: :search_products,
           value: %AshBaml.Examples.BamlClient.Types.SearchProducts{
             query: message,
             category: nil,
             max_price: Decimal.new("100")
           }
         }}

      length(history) == 1 ->
        # After search, add to cart
        {:ok,
         %Ash.Union{
           type: :add_to_cart,
           value: %AshBaml.Examples.BamlClient.Types.AddToCart{
             product_id: "PROD-001",
             quantity: 1
           }
         }}

      length(history) >= 2 ->
        # After adding to cart, we're done
        {:ok,
         %Ash.Union{
           type: :done,
           value: %{
             response: "I've added that to your cart. Would you like to checkout?",
             cart_ready: true
           }
         }}

      true ->
        {:ok,
         %Ash.Union{
           type: :done,
           value: %{response: "How can I help you shop today?"}
         }}
    end
  end
end
