defmodule AshBaml.Type.Stream do
  @constraints [
    element_type: [
      type: Ash.OptionsHelpers.ash_type(),
      doc: """
      The type of elements ultimately emitted by the Stream.

      For documentation and validation purposes. While the stream may emit
      partial results during iteration, this specifies the final complete
      type that will be produced.

      Example:

          action :chat_agent_stream, AshBaml.Type.Stream do
            constraints [
              element_type: MyApp.BamlClient.Types.Reply
            ]
          end
      """
    ]
  ]

  @moduledoc """
  An Ash type for BAML streaming actions.

  Represents a Stream that emits chunks as they arrive from the LLM.

  ## Constraints

  #{Spark.Options.docs(@constraints)}
  """

  use Ash.Type

  @doc """
  Returns the constraint schema for this type.

  Defines the `element_type` constraint that specifies the type of elements
  emitted by the Stream.
  """
  @impl true
  def constraints, do: @constraints

  @doc """
  Returns the storage type for this custom type.

  Streams are stored as `:any` since they are runtime values that don't
  get persisted to a database.
  """
  @impl true
  def storage_type(_), do: :any

  @doc """
  Initializes and validates the type constraints.

  Verifies that the `element_type` constraint (if provided) is a valid Ash type.
  This runs at compile-time when the type is defined.
  """
  @impl true
  def init(constraints) do
    case constraints[:element_type] do
      nil ->
        {:ok, constraints}

      element_type ->
        type = Ash.Type.get_type(element_type)

        if Ash.Type.ash_type?(type) do
          {:ok, Keyword.put(constraints, :element_type, type)}
        else
          {:error, "element_type must be a valid Ash type, got: #{inspect(element_type)}"}
        end
    end
  end

  @doc """
  Casts input values to a Stream.

  Called by Ash when validating action inputs. Verifies that the provided
  value is an Elixir Stream struct.
  """
  @impl true
  def cast_input(value, _constraints) do
    if is_struct(value, Stream) do
      {:ok, value}
    else
      {:error, "Expected a Stream, got: #{inspect(value)}"}
    end
  end

  @doc """
  Casts values loaded from storage.

  Since Streams are not stored, this simply returns the value as-is.
  """
  @impl true
  def cast_stored(value, _), do: {:ok, value}

  @doc """
  Dumps values to their native storage representation.

  Since Streams are not stored, this simply returns the value as-is.
  """
  @impl true
  def dump_to_native(value, _), do: {:ok, value}

  @doc """
  Checks if a value matches this type without full validation.

  Returns true if the value is a Stream struct, false otherwise.
  Used by Ash for type checking and introspection.
  """
  @impl true
  def matches_type?(value, _constraints) do
    is_struct(value, Stream)
  end

  @doc """
  Applies constraints to validate the value.

  Called by Ash to ensure the value conforms to the type's constraints.
  For Streams, this verifies the value is a Stream struct.
  """
  @impl true
  def apply_constraints(nil, _), do: {:ok, nil}

  def apply_constraints(value, _constraints) do
    if is_struct(value, Stream) do
      {:ok, value}
    else
      {:error, "must be a Stream"}
    end
  end
end
