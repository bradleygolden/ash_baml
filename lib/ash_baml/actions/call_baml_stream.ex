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
  # ## Process Lifecycle
  #
  # The BAML client's `stream/2` function spawns a background process to handle
  # streaming responses. This process sends messages to the parent process (self())
  # using the pattern `{ref, :chunk, data}` or `{ref, :done, result}`.
  #
  # ### Known Limitation: Process Cleanup
  #
  # The BAML Elixir client (v1.0.0-pre.23) does not return a process reference
  # from `stream/2`, which prevents explicit process termination on early stream
  # consumption halts. The `cleanup_stream/1` function flushes the mailbox to
  # prevent message accumulation but cannot terminate the BAML process.
  #
  # Impact:
  # - If a stream is created but never fully consumed, the BAML process may
  #   continue running until it completes or times out (30s default).
  # - Mailbox cleanup prevents memory leaks from unconsumed messages.
  # - This is acceptable for typical streaming scenarios where streams are
  #   consumed to completion or timeout naturally.
  #
  # Future improvement: When BAML Elixir client exposes process references,
  # update cleanup_stream/1 to explicitly terminate spawned processes.
  #
  defp start_streaming(function_module, arguments) do
    parent = self()
    ref = make_ref()

    function_module.stream(arguments, fn
      {:partial, partial_result} ->
        send(parent, {ref, :chunk, partial_result})

      {:done, final_result} ->
        send(parent, {ref, :done, {:ok, final_result}})

      {:error, error} ->
        send(parent, {ref, :done, {:error, error}})
    end)

    {ref, :streaming}
  end

  defp stream_next({ref, :streaming}) do
    receive do
      {^ref, :chunk, chunk} ->
        if valid_chunk?(chunk) do
          {[chunk], {ref, :streaming}}
        else
          {[], {ref, :streaming}}
        end

      {^ref, :done, {:ok, final_result}} ->
        {[final_result], {ref, :done}}

      {^ref, :done, {:error, reason}} ->
        {:halt, {ref, {:error, reason}}}
    after
      @default_stream_timeout ->
        # Stream timeout - BAML process may have crashed or stalled
        {:halt,
         {ref,
          {:error,
           "Stream timeout after #{@default_stream_timeout}ms - BAML process may have crashed"}}}
    end
  end

  defp stream_next({ref, :done}) do
    {:halt, {ref, :done}}
  end

  defp stream_next({ref, {:error, reason}}) do
    {:halt, {ref, {:error, reason}}}
  end

  # Cleans up stream resources by flushing mailbox messages.
  #
  # Note: This only flushes messages. It cannot terminate the BAML streaming
  # process as the client does not expose process references. See module docs
  # for start_streaming/2 for full context on process lifecycle limitations.
  defp cleanup_stream({ref, _status}) do
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
