defmodule AshBaml.TypeGeneratorTest do
  use ExUnit.Case, async: true

  alias AshBaml.TypeGenerator

  describe "generate_typed_struct/4" do
    test "generates basic struct with simple fields" do
      class_def = %{
        "fields" => %{
          "name" => {:primitive, :string},
          "age" => {:primitive, :integer}
        }
      }

      result =
        TypeGenerator.generate_typed_struct(
          "User",
          class_def,
          TestApp.Types.User,
          source_file: "test.baml"
        )

      assert result =~ "defmodule TestApp.Types.User"
      assert result =~ "use Ash.TypedStruct"
      assert result =~ "field :name, :string"
      assert result =~ "field :age, :integer"
      assert result =~ "Generated from BAML class: User"
      assert result =~ "Source: test.baml"
    end

    test "converts field names to snake_case" do
      class_def = %{
        "fields" => %{
          "firstName" => {:primitive, :string},
          "LastName" => {:primitive, :string}
        }
      }

      result =
        TypeGenerator.generate_typed_struct("User", class_def, TestApp.Types.User)

      assert result =~ "field :first_name, :string"
      assert result =~ "field :last_name, :string"
    end

    test "handles optional fields with allow_nil?: true" do
      class_def = %{
        "fields" => %{
          "optional_field" => {:optional, {:primitive, :string}},
          "required_field" => {:primitive, :string}
        }
      }

      result =
        TypeGenerator.generate_typed_struct("Test", class_def, TestApp.Types.Test)

      assert result =~ "field :optional_field, :string, allow_nil?: true"
      assert result =~ "field :required_field, :string, allow_nil?: false"
    end

    test "handles list types with :array" do
      class_def = %{
        "fields" => %{
          "tags" => {:list, {:primitive, :string}},
          "scores" => {:list, {:primitive, :integer}}
        }
      }

      result =
        TypeGenerator.generate_typed_struct("Test", class_def, TestApp.Types.Test)

      assert result =~ "field :tags, {:array, :string}"
      assert result =~ "field :scores, {:array, :integer}"
    end

    test "handles nested list types" do
      class_def = %{
        "fields" => %{
          "matrix" => {:list, {:list, {:primitive, :integer}}}
        }
      }

      result =
        TypeGenerator.generate_typed_struct("Test", class_def, TestApp.Types.Test)

      assert result =~ "field :matrix, {:array, {:array, :integer}}"
    end

    test "handles class references" do
      class_def = %{
        "fields" => %{
          "address" => {:class, "Address"},
          "profile" => {:class, "UserProfile"}
        }
      }

      result =
        TypeGenerator.generate_typed_struct("User", class_def, TestApp.Types.User)

      assert result =~ "field :address, TestApp.Types.Address"
      assert result =~ "field :profile, TestApp.Types.UserProfile"
    end

    test "handles enum references" do
      class_def = %{
        "fields" => %{
          "status" => {:enum, "Status"},
          "priority" => {:enum, "Priority"}
        }
      }

      result =
        TypeGenerator.generate_typed_struct("Task", class_def, TestApp.Types.Task)

      assert result =~ "field :status, TestApp.Types.Status"
      assert result =~ "field :priority, TestApp.Types.Priority"
    end

    test "handles unknown types as :any" do
      class_def = %{
        "fields" => %{
          "unknown" => {:unknown_type, "Something"}
        }
      }

      result =
        TypeGenerator.generate_typed_struct("Test", class_def, TestApp.Types.Test)

      assert result =~ "field :unknown, :any"
    end

    test "handles all primitive types" do
      class_def = %{
        "fields" => %{
          "str" => {:primitive, :string},
          "int" => {:primitive, :integer},
          "flt" => {:primitive, :float},
          "bool" => {:primitive, :boolean}
        }
      }

      result =
        TypeGenerator.generate_typed_struct("Test", class_def, TestApp.Types.Test)

      assert result =~ "field :str, :string"
      assert result =~ "field :int, :integer"
      assert result =~ "field :flt, :float"
      assert result =~ "field :bool, :boolean"
    end

    test "handles nil primitive type as :any" do
      class_def = %{
        "fields" => %{
          "unknown" => {:primitive, nil}
        }
      }

      result =
        TypeGenerator.generate_typed_struct("Test", class_def, TestApp.Types.Test)

      assert result =~ "field :unknown, :any"
    end

    test "handles unknown primitive type as :any" do
      class_def = %{
        "fields" => %{
          "unknown" => {:primitive, :unknown}
        }
      }

      result =
        TypeGenerator.generate_typed_struct("Test", class_def, TestApp.Types.Test)

      assert result =~ "field :unknown, :any"
    end

    test "includes field description when available" do
      class_def = %{
        "fields" => %{
          "name" => {:primitive, :string, %{"description" => "User's full name"}}
        }
      }

      result =
        TypeGenerator.generate_typed_struct("User", class_def, TestApp.Types.User)

      assert result =~ ~s(description: "User's full name")
    end

    test "omits description option when not available" do
      class_def = %{
        "fields" => %{
          "name" => {:primitive, :string}
        }
      }

      result =
        TypeGenerator.generate_typed_struct("User", class_def, TestApp.Types.User)

      refute result =~ "description:"
    end

    test "handles empty fields map" do
      class_def = %{"fields" => %{}}

      result =
        TypeGenerator.generate_typed_struct("Empty", class_def, TestApp.Types.Empty)

      assert result =~ "defmodule TestApp.Types.Empty"
      assert result =~ "use Ash.TypedStruct"
      assert result =~ "typed_struct do"
      refute result =~ "field :"
    end

    test "handles missing fields key with nil fields" do
      class_def = %{}

      result =
        TypeGenerator.generate_typed_struct("Empty", class_def, TestApp.Types.Empty)

      assert result =~ "defmodule TestApp.Types.Empty"
      refute result =~ "field :"
    end

    test "defaults source_file to 'unknown' when not provided" do
      class_def = %{"fields" => %{}}

      result = TypeGenerator.generate_typed_struct("Test", class_def, TestApp.Types.Test)

      assert result =~ "Source: unknown"
    end

    test "handles complex nested optional list of classes" do
      class_def = %{
        "fields" => %{
          "items" => {:optional, {:list, {:class, "Item"}}}
        }
      }

      result =
        TypeGenerator.generate_typed_struct("Container", class_def, TestApp.Types.Container)

      assert result =~ "field :items, {:array, TestApp.Types.Item}, allow_nil?: true"
    end
  end

  describe "generate_enum/4" do
    test "generates basic enum with simple variants" do
      result =
        TypeGenerator.generate_enum(
          "Status",
          ["pending", "active", "completed"],
          TestApp.Types.Status,
          source_file: "test.baml"
        )

      assert result =~ "defmodule TestApp.Types.Status"
      assert result =~ "use Ash.Type.Enum, values: [:pending, :active, :completed]"
      assert result =~ "Generated from BAML enum: Status"
      assert result =~ "Source: test.baml"
      assert result =~ "- `:pending` - pending"
      assert result =~ "- `:active` - active"
      assert result =~ "- `:completed` - completed"
    end

    test "converts variant names to snake_case atoms" do
      result =
        TypeGenerator.generate_enum(
          "Priority",
          ["HighPriority", "MediumPriority", "LowPriority"],
          TestApp.Types.Priority
        )

      assert result =~ "values: [:high_priority, :medium_priority, :low_priority]"
      assert result =~ "- `:high_priority` - HighPriority"
      assert result =~ "- `:medium_priority` - MediumPriority"
      assert result =~ "- `:low_priority` - LowPriority"
    end

    test "handles single variant enum" do
      result = TypeGenerator.generate_enum("Single", ["only"], TestApp.Types.Single)

      assert result =~ "values: [:only]"
      assert result =~ "- `:only` - only"
    end

    test "handles empty variants list" do
      result = TypeGenerator.generate_enum("Empty", [], TestApp.Types.Empty)

      assert result =~ "values: []"
      refute result =~ "- `:"
    end

    test "defaults source_file to 'unknown' when not provided" do
      result = TypeGenerator.generate_enum("Test", ["a"], TestApp.Types.Test)

      assert result =~ "Source: unknown"
    end

    test "preserves original variant names in documentation" do
      result =
        TypeGenerator.generate_enum("Test", ["UPPER_CASE", "mixedCase"], TestApp.Types.Test)

      assert result =~ "- `:upper_case` - UPPER_CASE"
      assert result =~ "- `:mixed_case` - mixedCase"
    end
  end
end
