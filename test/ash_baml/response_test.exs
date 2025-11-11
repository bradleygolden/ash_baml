defmodule AshBaml.ResponseTest do
  use ExUnit.Case, async: true

  alias AshBaml.Response

  describe "new/2" do
    test "creates Response with nil collector" do
      data = %{result: "test result"}

      response = Response.new(data, nil)

      assert %Response{} = response
      assert response.data == data
      assert response.collector == nil
      assert response.usage == nil
      assert response.model_name == nil
      assert response.provider == nil
      assert response.client_name == nil
      assert response.timing == nil
      assert response.num_attempts == nil
      assert response.function_name == nil
      assert response.request_id == nil
    end

    test "creates Response struct with all fields defined" do
      data = %{result: "test result"}

      response = Response.new(data, nil)

      assert Map.has_key?(response, :data)
      assert Map.has_key?(response, :usage)
      assert Map.has_key?(response, :collector)
      assert Map.has_key?(response, :model_name)
      assert Map.has_key?(response, :provider)
      assert Map.has_key?(response, :client_name)
      assert Map.has_key?(response, :timing)
      assert Map.has_key?(response, :num_attempts)
      assert Map.has_key?(response, :function_name)
      assert Map.has_key?(response, :request_id)
    end
  end

  describe "unwrap/1" do
    test "extracts data from Response struct" do
      response = %Response{data: "test data"}

      assert Response.unwrap(response) == "test data"
    end

    test "returns data unchanged if not wrapped" do
      data = "test data"

      assert Response.unwrap(data) == data
    end

    test "unwraps complex data structures" do
      data = %{nested: %{value: 123}, list: [1, 2, 3]}
      response = %Response{data: data}

      assert Response.unwrap(response) == data
    end
  end

  describe "usage/1" do
    test "extracts usage from Response struct" do
      usage = %{input_tokens: 10, output_tokens: 5, total_tokens: 15}
      response = %Response{usage: usage}

      assert Response.usage(response) == usage
    end

    test "returns nil if usage is nil" do
      response = %Response{usage: nil}

      assert Response.usage(response) == nil
    end
  end

  describe "struct fields" do
    test "all observability fields accept nil values" do
      response = %Response{
        data: "test",
        usage: nil,
        collector: nil,
        model_name: nil,
        provider: nil,
        client_name: nil,
        timing: nil,
        num_attempts: nil,
        function_name: nil,
        request_id: nil
      }

      assert %Response{} = response
    end

    test "timing field accepts map with required keys" do
      timing = %{
        duration_ms: 234,
        start_time_utc_ms: 1_699_123_456_789
      }

      response = %Response{
        data: "test",
        timing: timing
      }

      assert response.timing == timing
      assert response.timing.duration_ms == 234
    end

    test "timing field accepts map with optional time_to_first_token_ms" do
      timing = %{
        duration_ms: 234,
        start_time_utc_ms: 1_699_123_456_789,
        time_to_first_token_ms: 150
      }

      response = %Response{
        data: "test",
        timing: timing
      }

      assert response.timing.time_to_first_token_ms == 150
    end
  end

  describe "backward compatibility" do
    test "Response struct works with only original fields" do
      data = %{result: "test"}
      usage = %{input_tokens: 10, output_tokens: 5, total_tokens: 15}

      response = %Response{
        data: data,
        usage: usage,
        collector: nil
      }

      assert response.data == data
      assert response.usage == usage
      assert response.collector == nil
    end

    test "accessing new fields on old Response returns nil" do
      response = %Response{
        data: "test",
        usage: %{input_tokens: 10, output_tokens: 5, total_tokens: 15}
      }

      assert response.model_name == nil
      assert response.provider == nil
      assert response.timing == nil
    end
  end
end
