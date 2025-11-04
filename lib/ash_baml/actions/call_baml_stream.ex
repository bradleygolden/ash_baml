defmodule AshBaml.Actions.CallBamlStream do
  @moduledoc """
  Action implementation that calls BAML functions with streaming.

  This module wraps BAML's streaming API in an Elixir Stream, allowing
  actions to return token-by-token results from LLM calls.
  """

  use Ash.Resource.Actions.Implementation

  @default_stream_timeout 30_000

  @doc """
  Executes the BAML function with streaming.

  Returns `{:ok, stream}` where stream is an Elixir Stream that emits
  chunks as they arrive from the LLM.
  """
  @impl true
  def run(input, opts, _context) do
    client_module = AshBaml.Info.baml_client_module(input.resource)
    function_name = Keyword.fetch!(opts, :function)
    function_module = Module.concat(client_module, function_name)

    if Code.ensure_loaded?(function_module) do
      stream = create_stream(function_module, input.arguments)
      {:ok, stream}
    else
      build_module_not_found_error(input.resource, function_name, client_module, function_module)
    end
  end

  defp create_stream(function_module, arguments) do
    Stream.resource(
      fn -> start_streaming(function_module, arguments) end,
      fn state -> stream_next(state) end,
      fn state -> cleanup_stream(state) end
    )
  end

  # Creates a stream that communicates via message passing with a BAML streaming process.
  #
  # ## Process Lifecycle and Automatic Cleanup
  #
  # The BAML client's `stream/2` function returns `{:ok, pid}` representing the streaming
  # process. This process sends messages to the parent process (self()) using the pattern
  # `{ref, :chunk, data}` or `{ref, :done, result}`.
  #
  # ### Automatic Stream Cancellation
  #
  # When the stream consumer process exits or the stream is halted early,
  # the `cleanup_stream/1` function is automatically called by `Stream.resource/3`.
  # This triggers `BamlElixir.Stream.cancel/1` to stop the underlying LLM generation,
  # preventing unnecessary API calls and resource usage.
  #
  # Benefits:
  # - Stream cancellation stops ongoing LLM generation
  # - Significantly reduces wasted tokens vs generating the entire response
  # - Automatic cleanup on stream consumer exit or GC
  # - Graceful cancellation via Rust TripWire mechanism
  #
  # Note: Due to async message passing, some chunks may already be generated
  # and queued before cancellation takes effect. These are flushed from the mailbox.
  #
  defp start_streaming(function_module, arguments) do
    parent = self()
    ref = make_ref()

    case function_module.stream(arguments, fn
           {:partial, partial_result} ->
             send(parent, {ref, :chunk, partial_result})

           {:done, final_result} ->
             send(parent, {ref, :done, {:ok, final_result}})

           {:error, error} ->
             send(parent, {ref, :done, {:error, error}})
         end) do
      {:ok, stream_pid} ->
        {ref, stream_pid, :streaming}

      {:error, reason} ->
        {ref, nil, {:error, reason}}
    end
  end

  defp stream_next({ref, stream_pid, :streaming}) do
    receive do
      {^ref, :chunk, chunk} ->
        if valid_chunk?(chunk) do
          {[chunk], {ref, stream_pid, :streaming}}
        else
          {[], {ref, stream_pid, :streaming}}
        end

      {^ref, :done, {:ok, final_result}} ->
        {[final_result], {ref, stream_pid, :done}}

      {^ref, :done, {:error, reason}} ->
        {:halt, {ref, stream_pid, {:error, reason}}}
    after
      @default_stream_timeout ->
        BamlElixir.Stream.cancel(stream_pid, :timeout)

        {:halt,
         {ref, stream_pid,
          {:error,
           "Stream timeout after #{@default_stream_timeout}ms - BAML process may have crashed"}}}
    end
  end

  defp stream_next({ref, stream_pid, :done}) do
    {:halt, {ref, stream_pid, :done}}
  end

  defp stream_next({ref, stream_pid, {:error, reason}}) do
    {:halt, {ref, stream_pid, {:error, reason}}}
  end

  # Cleans up stream resources by canceling the BAML streaming process.
  #
  # This function is automatically called by Stream.resource/3 when:
  # - The stream consumer stops early (e.g., Enum.take/2)
  # - An exception occurs during stream consumption
  # - The stream consumer process exits
  #
  # Canceling the stream triggers the Rust TripWire, immediately stopping
  # LLM token generation and preventing wasted API calls.
  #
  # Note: If the stream has already completed normally, the process will
  # have exited and cancellation is unnecessary (and would fail).
  defp cleanup_stream({ref, stream_pid, status}) do
    if status == :streaming do
      # Use catch_exit to handle the case where the process exits
      # between our check and the cancel call (race condition)
      try do
        if Process.alive?(stream_pid) do
          BamlElixir.Stream.cancel(stream_pid, :consumer_stopped)
        end
      catch
        :exit, _ ->
          # Process already exited, cancellation not needed
          :ok
      end
    end

    flush_stream_messages(ref)
    :ok
  end

  defp flush_stream_messages(ref, max_iterations \\ 10_000) do
    flush_stream_messages_loop(ref, max_iterations)
  end

  defp flush_stream_messages_loop(_ref, 0), do: :ok

  defp flush_stream_messages_loop(ref, remaining) do
    receive do
      {^ref, _, _} -> flush_stream_messages_loop(ref, remaining - 1)
    after
      0 -> :ok
    end
  end

  # Validates that a chunk has usable content for streaming.
  # BAML sends partial chunks during progressive parsing where some fields may be nil.
  # During streaming, fields might be nil while content is being built.
  # We emit chunks as long as content has a value, since that's the primary field
  # being streamed. Fields are typically only known when parsing completes.
  defp valid_chunk?(chunk) when is_struct(chunk) do
    content = Map.get(chunk, :content)

    case content do
      nil -> false
      _ -> true
    end
  end

  defp valid_chunk?(_chunk), do: true

  defp build_module_not_found_error(resource, function_name, client_module, function_module) do
    {:error,
     """
     BAML function module not found: #{inspect(function_module)}

     Resource: #{inspect(resource)}
     Function: #{inspect(function_name)}
     Client Module: #{inspect(client_module)}

     Make sure:
     1. You have a BAML file with a function named #{function_name}
     2. Your client module (#{inspect(client_module)}) uses BamlElixir.Client
     3. The client has successfully parsed your BAML files
     """}
  end
end
