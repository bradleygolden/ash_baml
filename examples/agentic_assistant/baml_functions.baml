// BAML function definitions for the agentic assistant examples
//
// These would live in your baml_src/ directory and define:
// 1. The tool types (classes)
// 2. The decision functions that return unions of tools

// ============================================================
// Customer Support Agent Types
// ============================================================

class LookupOrder {
  order_id string @description("The order ID to look up")
}

class CreateTicket {
  issue string @description("Description of the issue")
  priority string @description("Priority level: low, normal, high, urgent")
  category string @description("Category: technical, billing, shipping, other")
}

class EscalateToHuman {
  reason string @description("Why this needs human attention")
  urgency string @description("Urgency level: normal, high, critical")
}

class Done {
  response string @description("Final response to the user")
  satisfied bool @description("Whether the user's needs were met")
}

// ============================================================
// Customer Support Decision Function
// ============================================================

function DecideNextSupportAction(
  message: string,
  history: string
) -> LookupOrder | CreateTicket | EscalateToHuman | Done {
  client GPT4

  prompt #"
    You are a customer support agent. Based on the conversation so far,
    decide what action to take next.

    Customer Message:
    {{ message }}

    Conversation History:
    {{ history }}

    Available Actions:
    1. LookupOrder - Look up order information by order ID
    2. CreateTicket - Create a support ticket for tracking
    3. EscalateToHuman - Escalate to a human agent
    4. Done - Complete the conversation

    Choose the most appropriate action and provide the necessary parameters.
    If the customer's issue is resolved, use Done.
  "#
}

// ============================================================
// Shopping Assistant Types
// ============================================================

class SearchProducts {
  query string @description("Search query for products")
  category string? @description("Optional category filter")
  max_price float? @description("Optional maximum price")
}

class AddToCart {
  product_id string @description("ID of the product to add")
  quantity int @description("Quantity to add")
}

class RemoveFromCart {
  product_id string @description("ID of the product to remove")
}

class Checkout {
  payment_method string @description("Payment method to use")
  shipping_address_id string? @description("Shipping address ID")
}

// ============================================================
// Shopping Assistant Decision Function
// ============================================================

function DecideNextShoppingAction(
  message: string,
  history: string,
  budget: float?,
  cart_items: string
) -> SearchProducts | AddToCart | RemoveFromCart | Checkout | Done {
  client GPT4

  prompt #"
    You are a shopping assistant helping a customer find and purchase products.

    Customer Message:
    {{ message }}

    Budget: {{ budget || "not specified" }}
    Current Cart: {{ cart_items }}

    Conversation History:
    {{ history }}

    Available Actions:
    1. SearchProducts - Search for products matching criteria
    2. AddToCart - Add a product to the cart
    3. RemoveFromCart - Remove a product from the cart
    4. Checkout - Proceed to checkout
    5. Done - Complete the shopping session

    Help the customer find what they need within their budget.
    Choose the most appropriate action.
  "#
}

// ============================================================
// Usage Notes
// ============================================================

// After defining these functions, run:
//   mix ash_baml.gen.types YourApp.BamlClient
//
// This generates:
//   - YourApp.BamlClient.Types.LookupOrder
//   - YourApp.BamlClient.Types.CreateTicket
//   - YourApp.BamlClient.Types.SearchProducts
//   - etc...
//
// Then use auto-generated actions:
//
//   baml do
//     client_module YourApp.BamlClient
//     import_functions [:DecideNextSupportAction, :DecideNextShoppingAction]
//   end
//
// This auto-generates:
//   - :decide_next_support_action (regular)
//   - :decide_next_support_action_stream (streaming)
//   - :decide_next_shopping_action (regular)
//   - :decide_next_shopping_action_stream (streaming)
