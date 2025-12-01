defmodule AshBaml.Actions.CallBamlStreamTest do
  use ExUnit.Case, async: true

  alias AshBaml.Actions.CallBamlStream

  defmodule MockStreamResource do
    use Ash.Resource,
      domain: nil,
      extensions: [AshBaml.Resource]

    baml do
      client_module(AshBaml.Test.BamlClient)
    end
  end

  defmodule TestChunk do
    defstruct [:content]
  end

  describe "run/3" do
    test "returns error when function module does not exist" do
      input = %{resource: MockStreamResource, arguments: %{}}
      opts = [function: :NonExistentFunction]

      assert {:error, error} = CallBamlStream.run(input, opts, %{})
      assert error =~ "BAML function module not found"
      assert error =~ "NonExistentFunction"
    end

    @tag :integration
    test "returns stream when function exists" do
      input = %{resource: MockStreamResource, arguments: %{prompt: "test"}}
      opts = [function: :TestFunction]

      assert {:ok, stream} = CallBamlStream.run(input, opts, %{})
      assert is_function(stream)
    end
  end

  describe "streaming behavior" do
    test "streams chunks successfully" do
      stream =
        Stream.resource(
          fn ->
            ref = make_ref()
            parent = self()
            pid = spawn(fn -> :ok end)

            send(parent, {ref, :chunk, %{content: "chunk1"}})
            send(parent, {ref, :chunk, %{content: "chunk2"}})
            send(parent, {ref, :done, {:ok, %{content: "final"}}})

            {ref, pid, :streaming}
          end,
          fn
            {ref, pid, :streaming} ->
              receive do
                {^ref, :chunk, chunk} ->
                  {[chunk], {ref, pid, :streaming}}

                {^ref, :done, {:ok, final}} ->
                  {[final], {ref, pid, :done}}

                {^ref, :done, {:error, reason}} ->
                  {:halt, {ref, pid, {:error, reason}}}
              after
                100 ->
                  {:halt, {ref, pid, {:error, "timeout"}}}
              end

            {ref, pid, :done} ->
              {:halt, {ref, pid, :done}}

            state ->
              {:halt, state}
          end,
          fn _state -> :ok end
        )

      results = Enum.to_list(stream)
      assert length(results) == 3
      assert Enum.at(results, 0) == %{content: "chunk1"}
      assert Enum.at(results, 1) == %{content: "chunk2"}
      assert Enum.at(results, 2) == %{content: "final"}
    end

    test "handles errors during streaming" do
      stream =
        Stream.resource(
          fn ->
            ref = make_ref()
            parent = self()
            pid = spawn(fn -> :ok end)

            send(parent, {ref, :chunk, %{content: "before error"}})
            send(parent, {ref, :done, {:error, "stream error"}})

            {ref, pid, :streaming}
          end,
          fn
            {ref, pid, :streaming} ->
              receive do
                {^ref, :chunk, chunk} ->
                  {[chunk], {ref, pid, :streaming}}

                {^ref, :done, {:ok, final}} ->
                  {[final], {ref, pid, :done}}

                {^ref, :done, {:error, _reason}} = err ->
                  {:halt, {ref, pid, err}}
              after
                100 ->
                  {:halt, {ref, pid, {:error, "timeout"}}}
              end

            state ->
              {:halt, state}
          end,
          fn _state -> :ok end
        )

      results = Enum.to_list(stream)
      assert results == [%{content: "before error"}]
    end

    test "filters out invalid chunks with nil content" do
      stream =
        Stream.resource(
          fn ->
            ref = make_ref()
            parent = self()
            pid = spawn(fn -> :ok end)

            send(parent, {ref, :chunk, %TestChunk{content: nil}})
            send(parent, {ref, :chunk, %TestChunk{content: "valid"}})
            send(parent, {ref, :done, {:ok, %TestChunk{content: "final"}}})

            {ref, pid, :streaming}
          end,
          fn
            {ref, pid, :streaming} ->
              receive do
                {^ref, :chunk, chunk} ->
                  if is_struct(chunk) and is_nil(Map.get(chunk, :content)) do
                    {[], {ref, pid, :streaming}}
                  else
                    {[chunk], {ref, pid, :streaming}}
                  end

                {^ref, :done, {:ok, final}} ->
                  {[final], {ref, pid, :done}}

                {^ref, :done, {:error, reason}} ->
                  {:halt, {ref, pid, {:error, reason}}}
              after
                100 ->
                  {:halt, {ref, pid, {:error, "timeout"}}}
              end

            state ->
              {:halt, state}
          end,
          fn _state -> :ok end
        )

      results = Enum.to_list(stream)
      assert length(results) == 2
      assert Enum.at(results, 0) == %TestChunk{content: "valid"}
      assert Enum.at(results, 1) == %TestChunk{content: "final"}
    end

    test "handles early termination with Enum.take" do
      ref = make_ref()
      parent = self()
      pid = spawn(fn -> Process.sleep(:infinity) end)

      send(parent, {ref, :chunk, %{content: "1"}})
      send(parent, {ref, :chunk, %{content: "2"}})
      send(parent, {ref, :chunk, %{content: "3"}})
      send(parent, {ref, :chunk, %{content: "4"}})
      send(parent, {ref, :chunk, %{content: "5"}})

      cleanup_called = make_ref()

      stream =
        Stream.resource(
          fn -> {ref, pid, :streaming} end,
          fn
            {ref, pid, :streaming} ->
              receive do
                {^ref, :chunk, chunk} ->
                  {[chunk], {ref, pid, :streaming}}

                {^ref, :done, {:ok, final}} ->
                  {[final], {ref, pid, :done}}
              after
                100 ->
                  {:halt, {ref, pid, {:error, "timeout"}}}
              end

            state ->
              {:halt, state}
          end,
          fn _state ->
            send(parent, {cleanup_called, :cleanup_executed})
            :ok
          end
        )

      results = Enum.take(stream, 2)
      assert length(results) == 2
      assert Enum.at(results, 0) == %{content: "1"}
      assert Enum.at(results, 1) == %{content: "2"}

      receive do
        {^cleanup_called, :cleanup_executed} -> :ok
      after
        100 -> flunk("Cleanup function was not called")
      end

      Process.exit(pid, :kill)
    end

    test "handles initial stream error" do
      stream =
        Stream.resource(
          fn -> {make_ref(), nil, {:error, "Failed to start"}} end,
          fn
            {ref, pid, {:error, reason}} ->
              {:halt, {ref, pid, {:error, reason}}}

            state ->
              {:halt, state}
          end,
          fn _state -> :ok end
        )

      results = Enum.to_list(stream)
      assert results == []
    end
  end

  describe "cleanup behavior" do
    test "cleanup flushes messages from mailbox" do
      ref = make_ref()
      parent = self()

      send(parent, {ref, :chunk, "message1"})
      send(parent, {ref, :chunk, "message2"})
      send(parent, {ref, :done, "message3"})

      flush_stream_messages = fn flush_ref ->
        flush_loop = fn flush_loop_fn, remaining ->
          if remaining <= 0 do
            :ok
          else
            receive do
              {^flush_ref, _, _} -> flush_loop_fn.(flush_loop_fn, remaining - 1)
            after
              0 -> :ok
            end
          end
        end

        flush_loop.(flush_loop, 10_000)
      end

      flush_stream_messages.(ref)

      refute_receive {^ref, _, _}, 50
    end

    test "cleanup handles max iterations limit" do
      ref = make_ref()
      parent = self()

      for i <- 1..15_000 do
        send(parent, {ref, :chunk, "msg#{i}"})
      end

      flush_with_limit = fn flush_ref, max_iterations ->
        flush_loop = fn flush_loop_fn, remaining ->
          if remaining <= 0 do
            :ok
          else
            receive do
              {^flush_ref, _, _} -> flush_loop_fn.(flush_loop_fn, remaining - 1)
            after
              0 -> :ok
            end
          end
        end

        flush_loop.(flush_loop, max_iterations)
      end

      flush_with_limit.(ref, 10_000)

      message_count =
        Stream.unfold(0, fn count ->
          receive do
            {^ref, _, _} -> {count + 1, count + 1}
          after
            0 -> nil
          end
        end)
        |> Enum.to_list()
        |> List.last()
        |> Kernel.||(0)

      assert message_count == 5_000
    end
  end

  describe "valid_chunk?/1" do
    test "returns true for struct with non-nil content" do
      chunk = %{__struct__: TestStruct, content: "valid"}
      assert is_struct(chunk)
      assert not is_nil(Map.get(chunk, :content))
    end

    test "returns false for struct with nil content" do
      chunk = %{__struct__: TestStruct, content: nil}
      assert is_struct(chunk)
      assert is_nil(Map.get(chunk, :content))
    end

    test "returns true for non-struct values" do
      chunk = %{content: "test"}
      refute is_struct(chunk)
    end

    test "returns true for string chunks" do
      chunk = "simple string"
      refute is_struct(chunk)
    end
  end
end
