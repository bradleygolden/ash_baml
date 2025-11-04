# How to Add Streaming

Step-by-step guide to adding streaming support to BAML function calls.

## Why Streaming?

Streaming provides:
- **Immediate feedback**: Show results as they arrive
- **Better UX**: Users see progress, not loading spinners
- **Lower latency**: First token arrives faster than waiting for complete response

## Auto-Generated Streaming Actions

Every `import_functions` creates two actions:
- `:function_name` - Regular (waits for full response)
- `:function_name_stream` - Streaming (returns `Stream`)

### Example

```elixir
defmodule MyApp.Generator do
  use Ash.Resource,
    extensions: [AshBaml.Resource]

  baml do
    client :default
    import_functions [:GenerateStory]
  end

  # Auto-generates:
  # - :generate_story (returns complete Story)
  # - :generate_story_stream (returns Stream)
end
```

## Using Streaming Actions

### Basic Usage

```elixir
{:ok, stream} = MyApp.Generator
  |> Ash.ActionInput.for_action(:generate_story_stream, %{
    prompt: "Write a short story about a dragon"
  })
  |> Ash.run_action()

# Process stream
stream
|> Stream.each(fn chunk ->
  IO.write(chunk)
end)
|> Stream.run()
```

### In IEx

```elixir
iex> {:ok, stream} = MyApp.Generator
...>   |> Ash.ActionInput.for_action(:generate_story_stream, %{prompt: "..."})
...>   |> Ash.run_action()

iex> stream |> Enum.each(&IO.write/1)
# Outputs: Once upon a time, there was a dragon...
```

## Phoenix LiveView Integration

### Step 1: Create LiveView

```elixir
defmodule MyAppWeb.GeneratorLive do
  use MyAppWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, prompt: "", output: "", streaming: false)}
  end

  def handle_event("generate", %{"prompt" => prompt}, socket) do
    # Start streaming
    {:ok, stream} = MyApp.Generator
      |> Ash.ActionInput.for_action(:generate_story_stream, %{prompt: prompt})
      |> Ash.run_action()

    # Process stream asynchronously
    pid = self()
    Task.start(fn -> stream_to_liveview(stream, pid) end)

    {:noreply, assign(socket, output: "", streaming: true)}
  end

  def handle_info({:chunk, chunk}, socket) do
    {:noreply, assign(socket, output: socket.assigns.output <> chunk)}
  end

  def handle_info(:done, socket) do
    {:noreply, assign(socket, streaming: false)}
  end

  defp stream_to_liveview(stream, pid) do
    stream
    |> Stream.each(fn chunk ->
      send(pid, {:chunk, chunk})
    end)
    |> Stream.run()

    send(pid, :done)
  end
end
```

### Step 2: Create Template

```heex
<div>
  <form phx-submit="generate">
    <textarea name="prompt" placeholder="Enter prompt..." />
    <button type="submit">Generate</button>
  </form>

  <div class="output">
    <%= if @streaming do %>
      <div class="spinner">Generating...</div>
    <% end %>
    <pre><%= @output %></pre>
  </div>
</div>
```

## Phoenix Controller (Server-Sent Events)

```elixir
defmodule MyAppWeb.StreamController do
  use MyAppWeb, :controller

  def stream(conn, %{"prompt" => prompt}) do
    {:ok, stream} = MyApp.Generator
      |> Ash.ActionInput.for_action(:generate_story_stream, %{prompt: prompt})
      |> Ash.run_action()

    conn
    |> put_resp_content_type("text/event-stream")
    |> put_resp_header("cache-control", "no-cache")
    |> put_resp_header("connection", "keep-alive")
    |> send_chunked(200)
    |> stream_response(stream)
  end

  defp stream_response(conn, stream) do
    Enum.reduce_while(stream, conn, fn chunk, conn ->
      data = Jason.encode!(%{chunk: chunk})

      case Plug.Conn.chunk(conn, "data: #{data}\n\n") do
        {:ok, conn} ->
          {:cont, conn}

        {:error, :closed} ->
          {:halt, conn}
      end
    end)

    conn
  end
end
```

### Client-Side (JavaScript)

```javascript
const eventSource = new EventSource('/api/stream?prompt=' + encodeURIComponent(prompt));

eventSource.onmessage = (event) => {
  const data = JSON.parse(event.data);
  document.getElementById('output').textContent += data.chunk;
};

eventSource.onerror = () => {
  eventSource.close();
  console.log('Stream ended');
};
```

## Manual Streaming Action

Define streaming actions manually for custom logic:

```elixir
actions do
  action :generate_with_progress, AshBaml.Type.Stream do
    argument :prompt, :string

    run fn input, _ctx ->
      {:ok, stream} = __MODULE__
        |> Ash.ActionInput.for_action(:generate_story_stream, %{
          prompt: input.arguments.prompt
        })
        |> Ash.run_action()

      # Wrap stream with progress tracking
      tracked_stream = Stream.transform(stream, 0, fn chunk, count ->
        new_count = count + String.length(chunk)

        # Emit progress every 100 characters
        if rem(new_count, 100) < String.length(chunk) do
          IO.puts("Progress: #{new_count} characters")
        end

        {[chunk], new_count}
      end)

      {:ok, tracked_stream}
    end
  end
end
```

## Collecting Stream into Result

Sometimes you want to process the stream and return a final result:

```elixir
defmodule MyApp.StreamCollector do
  def generate_and_collect(prompt) do
    {:ok, stream} = MyApp.Generator
      |> Ash.ActionInput.for_action(:generate_story_stream, %{prompt: prompt})
      |> Ash.run_action()

    # Collect all chunks
    complete_text = stream
      |> Enum.to_list()
      |> Enum.join()

    {:ok, complete_text}
  end
end
```

## Error Handling in Streams

```elixir
def handle_stream(stream) do
  try do
    stream
    |> Stream.each(fn chunk ->
      process_chunk(chunk)
    end)
    |> Stream.run()

    :ok
  rescue
    error ->
      Logger.error("Stream processing failed: #{inspect(error)}")
      {:error, error}
  end
end
```

## Automatic Stream Cancellation

AshBaml automatically cancels the underlying LLM generation when the stream consumer stops or exits. This prevents wasted API calls and token usage.

### How It Works

When a stream is created with `Stream.resource/3`, the cleanup function automatically:
1. Detects when the consumer process exits or stops consuming
2. Cancels the underlying BAML streaming process
3. Stops LLM token generation via Rust TripWire mechanism
4. Flushes remaining messages from the mailbox

### Benefits

- **Cost savings**: Stops LLM generation when you stop consuming
- **Resource efficiency**: No hanging processes or orphaned API calls
- **Automatic**: No manual cleanup code needed

### When Cancellation Triggers

Stream cancellation happens automatically when:

**Process exits or crashes:**
```elixir
task = Task.async(fn ->
  {:ok, stream} = MyApp.Generator
    |> Ash.ActionInput.for_action(:generate_story_stream, %{prompt: "Long story..."})
    |> Ash.run_action()

  Enum.each(stream, fn chunk ->
    send_to_client(chunk)
  end)
end)

# If task is killed (e.g., user disconnects), stream automatically cancels
Task.shutdown(task, :brutal_kill)
```

### Important Notes

Due to asynchronous message passing, some chunks may already be generated and queued before cancellation takes effect. These chunks are automatically flushed from the mailbox. The benefit is still significant: cancellation stops ongoing generation rather than waiting for the entire response to complete.

## Custom Stream Implementation

For complete control, implement streaming from scratch:

```elixir
actions do
  action :custom_stream, AshBaml.Type.Stream do
    argument :prompt, :string

    run fn input, _ctx ->
      stream = Stream.resource(
        fn ->
          # Initialize: Call BAML client
          {:ok, baml_stream} = MyApp.BamlClient.generate_story_stream(%{
            prompt: input.arguments.prompt
          })

          baml_stream
        end,
        fn baml_stream ->
          # Emit: Get next chunk
          case Enum.take(baml_stream, 1) do
            [chunk] -> {[chunk], Stream.drop(baml_stream, 1)}
            [] -> {:halt, baml_stream}
          end
        end,
        fn _baml_stream ->
          # Cleanup
          :ok
        end
      )

      {:ok, stream}
    end
  end
end
```

## Testing Streaming

```elixir
defmodule MyApp.StreamingTest do
  use ExUnit.Case

  test "streams story generation" do
    {:ok, stream} = MyApp.Generator
      |> Ash.ActionInput.for_action(:generate_story_stream, %{
        prompt: "Test story"
      })
      |> Ash.run_action()

    chunks = Enum.to_list(stream)

    assert length(chunks) > 0
    assert Enum.all?(chunks, &is_binary/1)

    complete = Enum.join(chunks)
    assert String.length(complete) > 0
  end

  test "handles stream errors" do
    # Mock to return error stream
    expect(MyApp.BamlClientMock, :generate_story_stream, fn _ ->
      {:ok, Stream.map([1, 2, 3], fn _ ->
        raise "Simulated error"
      end)}
    end)

    {:ok, stream} = MyApp.Generator
      |> Ash.ActionInput.for_action(:generate_story_stream, %{prompt: "Test"})
      |> Ash.run_action()

    assert_raise RuntimeError, fn ->
      Enum.to_list(stream)
    end
  end
end
```

## Performance Tips

### 1. Buffer Small Chunks

```elixir
def buffer_chunks(stream, min_size \\ 100) do
  Stream.transform(stream, "", fn chunk, buffer ->
    new_buffer = buffer <> chunk

    if String.length(new_buffer) >= min_size do
      {[new_buffer], ""}
    else
      {[], new_buffer}
    end
  end)
  |> Stream.concat(fn -> Stream.emit_final_buffer() end)
end
```

### 2. Timeout Handling

```elixir
def stream_with_timeout(stream, timeout_ms \\ 30_000) do
  Stream.transform(stream, nil, fn chunk, _state ->
    Task.await(Task.async(fn -> chunk end), timeout_ms)
    {[chunk], nil}
  end)
end
```

### 3. Rate Limiting

```elixir
def rate_limit_stream(stream, delay_ms \\ 100) do
  Stream.transform(stream, nil, fn chunk, _state ->
    Process.sleep(delay_ms)
    {[chunk], nil}
  end)
end
```

## Next Steps

- [Configure Telemetry](configure-telemetry.md) - Monitor streaming performance
- [Tutorial: Get Started](../tutorials/01-get-started.md) - Basic streaming example
- [Topic: Actions](../topics/actions.md) - Understanding streaming actions

## Related

- [How to: Call BAML Function](call-baml-function.md) - Non-streaming calls
- [Topic: Actions](../topics/actions.md) - Action system overview
