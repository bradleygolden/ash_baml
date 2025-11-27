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
      assert response.raw_response == nil
      assert response.http_response_body == nil
      assert response.tags == nil
      assert response.log_type == nil
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
      assert Map.has_key?(response, :raw_response)
      assert Map.has_key?(response, :http_response_body)
      assert Map.has_key?(response, :tags)
      assert Map.has_key?(response, :log_type)
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

  describe "thinking/1" do
    test "extracts thinking content from http_response_body with thinking blocks" do
      http_body =
        Jason.encode!(%{
          "content" => [
            %{"type" => "thinking", "thinking" => "Let me think about this..."},
            %{"type" => "text", "text" => "The answer is 42"}
          ]
        })

      response = %Response{http_response_body: http_body}

      assert Response.thinking(response) == "Let me think about this..."
    end

    test "joins multiple thinking blocks with newline" do
      http_body =
        Jason.encode!(%{
          "content" => [
            %{"type" => "thinking", "thinking" => "First thought"},
            %{"type" => "text", "text" => "Some text"},
            %{"type" => "thinking", "thinking" => "Second thought"}
          ]
        })

      response = %Response{http_response_body: http_body}

      assert Response.thinking(response) == "First thought\nSecond thought"
    end

    test "returns nil if no thinking blocks present" do
      http_body =
        Jason.encode!(%{
          "content" => [
            %{"type" => "text", "text" => "Just regular text"}
          ]
        })

      response = %Response{http_response_body: http_body}

      assert Response.thinking(response) == nil
    end

    test "returns nil if http_response_body is nil" do
      response = %Response{http_response_body: nil}

      assert Response.thinking(response) == nil
    end

    test "returns nil if http_response_body is invalid JSON" do
      response = %Response{http_response_body: "not valid json"}

      assert Response.thinking(response) == nil
    end

    test "returns nil if http_response_body has no content array" do
      http_body = Jason.encode!(%{"model" => "claude-3", "id" => "msg_123"})
      response = %Response{http_response_body: http_body}

      assert Response.thinking(response) == nil
    end

    test "returns nil for non-Response values" do
      assert Response.thinking(nil) == nil
      assert Response.thinking("string") == nil
      assert Response.thinking(%{}) == nil
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
        request_id: nil,
        raw_response: nil,
        http_response_body: nil,
        tags: nil,
        log_type: nil
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
