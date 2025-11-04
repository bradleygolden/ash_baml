defmodule AshBaml.Type.StreamTest do
  use ExUnit.Case, async: true

  alias AshBaml.Type.Stream, as: StreamType

  describe "constraints/0" do
    test "returns constraint schema with element_type" do
      constraints = StreamType.constraints()

      assert is_list(constraints)
      assert Keyword.has_key?(constraints, :element_type)
      assert constraints[:element_type][:type] == Ash.OptionsHelpers.ash_type()
    end
  end

  describe "storage_type/1" do
    test "returns :any for empty constraints" do
      assert StreamType.storage_type([]) == :any
    end

    test "returns :any regardless of constraints" do
      constraints = [element_type: :string]
      assert StreamType.storage_type(constraints) == :any
    end
  end

  describe "init/1" do
    test "succeeds with no element_type constraint" do
      constraints = []
      assert {:ok, ^constraints} = StreamType.init(constraints)
    end

    test "succeeds with valid Ash type as element_type" do
      constraints = [element_type: :string]
      assert {:ok, result} = StreamType.init(constraints)
      assert result[:element_type] == Ash.Type.String
    end

    test "succeeds with custom Ash type module as element_type" do
      constraints = [element_type: Ash.Type.Integer]
      assert {:ok, result} = StreamType.init(constraints)
      assert result[:element_type] == Ash.Type.Integer
    end

    test "returns error for invalid element_type" do
      constraints = [element_type: NonExistentModule]
      assert {:error, message} = StreamType.init(constraints)
      assert message =~ "element_type must be a valid Ash type"
      assert message =~ "NonExistentModule"
    end
  end

  describe "cast_input/2" do
    test "succeeds when value is a Stream struct" do
      stream = Stream.map([1, 2, 3], & &1)
      assert {:ok, ^stream} = StreamType.cast_input(stream, [])
    end

    test "returns error when value is not a Stream" do
      assert {:error, message} = StreamType.cast_input(123, [])
      assert message =~ "Expected a Stream"
      assert message =~ "123"
    end

    test "returns error when value is a map" do
      assert {:error, message} = StreamType.cast_input(%{key: "value"}, [])
      assert message =~ "Expected a Stream"
    end

    test "returns error when value is a list" do
      assert {:error, message} = StreamType.cast_input([1, 2, 3], [])
      assert message =~ "Expected a Stream"
    end
  end

  describe "cast_stored/2" do
    test "returns value as-is" do
      stream = Stream.map([1, 2, 3], & &1)
      assert {:ok, ^stream} = StreamType.cast_stored(stream, [])
    end

    test "returns any value without validation" do
      assert {:ok, 123} = StreamType.cast_stored(123, [])
      assert {:ok, "string"} = StreamType.cast_stored("string", [])
    end
  end

  describe "dump_to_native/2" do
    test "returns value as-is" do
      stream = Stream.map([1, 2, 3], & &1)
      assert {:ok, ^stream} = StreamType.dump_to_native(stream, [])
    end

    test "returns any value without transformation" do
      assert {:ok, 123} = StreamType.dump_to_native(123, [])
      assert {:ok, "string"} = StreamType.dump_to_native("string", [])
    end
  end

  describe "matches_type?/2" do
    test "returns true for Stream struct" do
      stream = Stream.map([1, 2, 3], & &1)
      assert StreamType.matches_type?(stream, [])
    end

    test "returns false for non-Stream values" do
      refute StreamType.matches_type?(123, [])
      refute StreamType.matches_type?("string", [])
      refute StreamType.matches_type?([1, 2, 3], [])
      refute StreamType.matches_type?(%{key: "value"}, [])
    end

    test "constraints are ignored" do
      stream = Stream.map([1, 2, 3], & &1)
      assert StreamType.matches_type?(stream, element_type: :string)
    end
  end

  describe "apply_constraints/2" do
    test "allows nil values" do
      assert {:ok, nil} = StreamType.apply_constraints(nil, [])
    end

    test "succeeds when value is a Stream struct" do
      stream = Stream.map([1, 2, 3], & &1)
      assert {:ok, ^stream} = StreamType.apply_constraints(stream, [])
    end

    test "returns error when value is not a Stream" do
      assert {:error, "must be a Stream"} = StreamType.apply_constraints(123, [])
    end

    test "returns error for non-Stream structs" do
      date = ~D[2024-01-01]
      assert {:error, "must be a Stream"} = StreamType.apply_constraints(date, [])
    end

    test "constraints are ignored for validation" do
      stream = Stream.map([1, 2, 3], & &1)
      assert {:ok, ^stream} = StreamType.apply_constraints(stream, element_type: :string)
    end
  end
end
