#!/usr/bin/env elixir

# Manual test script for Helpdesk BAML functions
# Run with: mix run test_baml_functions.exs

IO.puts("\n=== Testing Helpdesk BAML Functions ===\n")

# Test 1: CategorizeTicket
IO.puts("Test 1: CategorizeTicket")
IO.puts("------------------------")

result1 =
  Helpdesk.Support.TicketAnalyzer
  |> Ash.ActionInput.for_action(:categorize_ticket, %{
    subject: "App crashes when uploading files",
    description: "The application crashes every time I try to upload a file larger than 10MB"
  })
  |> Ash.run_action()

case result1 do
  {:ok, category} ->
    IO.puts("✓ CategorizeTicket succeeded!")
    IO.inspect(category, label: "Result", pretty: true)
    IO.puts("\nFields:")
    IO.puts("  Category: #{category.category}")
    IO.puts("  Priority: #{category.priority}")
    IO.puts("  Reasoning: #{category.reasoning}")
    IO.puts("  Suggested Assignee: #{inspect(category.suggested_assignee)}")

  {:error, error} ->
    IO.puts("✗ CategorizeTicket failed!")
    IO.inspect(error, label: "Error")
end

IO.puts("\n")

# Test 2: AnalyzeSentiment
IO.puts("Test 2: AnalyzeSentiment")
IO.puts("------------------------")

result2 =
  Helpdesk.Support.TicketAnalyzer
  |> Ash.ActionInput.for_action(:analyze_sentiment, %{
    text: "I've been waiting 3 days for a response! This is unacceptable!"
  })
  |> Ash.run_action()

case result2 do
  {:ok, sentiment} ->
    IO.puts("✓ AnalyzeSentiment succeeded!")
    IO.inspect(sentiment, label: "Result", pretty: true)
    IO.puts("\nFields:")
    IO.puts("  Sentiment: #{sentiment.sentiment}")
    IO.puts("  Confidence: #{sentiment.confidence}")
    IO.puts("  Emotional Indicators: #{inspect(sentiment.emotional_indicators)}")
    IO.puts("  Requires Escalation: #{sentiment.requires_escalation}")

  {:error, error} ->
    IO.puts("✗ AnalyzeSentiment failed!")
    IO.inspect(error, label: "Error")
end

IO.puts("\n")

# Test 3: SuggestResponse
IO.puts("Test 3: SuggestResponse")
IO.puts("------------------------")

result3 =
  Helpdesk.Support.TicketAnalyzer
  |> Ash.ActionInput.for_action(:suggest_response, %{
    ticket_subject: "Billing question",
    ticket_description: "I was charged twice this month",
    customer_name: "Alice"
  })
  |> Ash.run_action()

case result3 do
  {:ok, suggestion} ->
    IO.puts("✓ SuggestResponse succeeded!")
    IO.inspect(suggestion, label: "Result", pretty: true)
    IO.puts("\nFields:")
    IO.puts("  Response Draft: #{String.slice(suggestion.response_draft, 0..100)}...")
    IO.puts("  Next Steps: #{inspect(suggestion.next_steps)}")
    IO.puts("  Resolution Time: #{suggestion.resolution_time}")
    IO.puts("  Requires Manager Review: #{suggestion.requires_manager_review}")

  {:error, error} ->
    IO.puts("✗ SuggestResponse failed!")
    IO.inspect(error, label: "Error")
end

IO.puts("\n")

# Test 4: Streaming Variant
IO.puts("Test 4: CategorizeTicket (Streaming)")
IO.puts("-------------------------------------")

result4 =
  Helpdesk.Support.TicketAnalyzer
  |> Ash.ActionInput.for_action(:categorize_ticket_stream, %{
    subject: "Feature request",
    description: "Add dark mode to the application"
  })
  |> Ash.run_action()

case result4 do
  {:ok, stream} ->
    IO.puts("✓ CategorizeTicketStream action succeeded!")
    IO.puts("Streaming chunks:")

    chunks =
      stream
      |> Enum.take(5)
      |> Enum.with_index(1)

    for {chunk, index} <- chunks do
      IO.puts("  Chunk #{index}: #{inspect(chunk)}")
    end

    IO.puts("  (showing first 5 chunks only)")

  {:error, error} ->
    IO.puts("✗ CategorizeTicketStream failed!")
    IO.inspect(error, label: "Error")
end

IO.puts("\n=== Testing Complete ===\n")
