defmodule AshBaml.IntegrationTest do
  use ExUnit.Case, async: false

  @moduletag :integration
  @moduletag timeout: 60_000

  # This test uses the actual BAML files and real baml_elixir code generation
  # It does NOT make real LLM API calls - we'll mock the NIF for now

  describe "end-to-end BAML integration" do
    test "can call BAML function through Ash action" do
      # This test verifies:
      # 1. BAML files are parsed by baml_elixir
      # 2. Modules are generated correctly
      # 3. AshBaml can call them
      # 4. Results are returned properly

      # Note: In a real test, you'd need OPENAI_API_KEY set
      # For now, we'll skip if not available
      # unless System.get_env("OPENAI_API_KEY") do
      #   IO.puts("Skipping integration test - OPENAI_API_KEY not set")
      #   :ok
      # else
      {:ok, result} =
        AshBaml.Test.TestResource
        |> Ash.ActionInput.for_action(:test_action, %{message: "Hello!"})
        |> Ash.run_action()

      assert %AshBaml.Test.BamlClient.Reply{} = result
      assert is_binary(result.content)
      assert is_float(result.confidence)
      # end
    end
  end
end
