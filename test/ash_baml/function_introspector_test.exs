defmodule AshBaml.FunctionIntrospectorTest do
  use ExUnit.Case, async: true

  alias AshBaml.FunctionIntrospector
  alias AshBaml.Test.BamlClient

  describe "get_function_names/1" do
    test "returns list of function names from BAML schema" do
      assert {:ok, function_names} = FunctionIntrospector.get_function_names(BamlClient)
      assert is_list(function_names)
      assert :TestFunction in function_names
      assert :MultiArgFunction in function_names
    end

    test "returns error when client module doesn't have __baml_src_path__" do
      defmodule InvalidClient do
        def not_a_baml_client, do: :ok
      end

      assert {:error, reason} = FunctionIntrospector.get_function_names(InvalidClient)
      assert reason =~ "does not implement __baml_src_path__"
    end
  end

  describe "get_function_metadata/2" do
    test "returns metadata for existing function" do
      assert {:ok, metadata} =
               FunctionIntrospector.get_function_metadata(BamlClient, :TestFunction)

      assert is_map(metadata)
      assert Map.has_key?(metadata, "params")
      assert Map.has_key?(metadata, "return_type")
    end

    test "returns params map with parameter types" do
      assert {:ok, metadata} =
               FunctionIntrospector.get_function_metadata(BamlClient, :TestFunction)

      assert is_map(metadata["params"])
      assert Map.has_key?(metadata["params"], "message")
    end

    test "returns return_type information" do
      assert {:ok, metadata} =
               FunctionIntrospector.get_function_metadata(BamlClient, :TestFunction)

      assert {:class, "Reply"} = metadata["return_type"]
    end

    test "returns error when function not found" do
      assert {:error, reason} =
               FunctionIntrospector.get_function_metadata(BamlClient, :NonExistentFunction)

      assert reason =~ "Function NonExistentFunction not found"
    end

    test "handles multi-arg functions" do
      assert {:ok, metadata} =
               FunctionIntrospector.get_function_metadata(BamlClient, :MultiArgFunction)

      assert map_size(metadata["params"]) == 3
      assert Map.has_key?(metadata["params"], "name")
      assert Map.has_key?(metadata["params"], "age")
      assert Map.has_key?(metadata["params"], "topic")
    end
  end

  describe "validate_function_exists/2" do
    test "returns :ok when function exists" do
      assert :ok = FunctionIntrospector.validate_function_exists(BamlClient, :TestFunction)
    end

    test "returns error when function does not exist" do
      assert {:error, reason} =
               FunctionIntrospector.validate_function_exists(BamlClient, :NonExistentFunction)

      assert reason =~ "BAML function :NonExistentFunction not found"
      assert reason =~ "Available functions:"
    end

    test "returns error when client module is invalid" do
      defmodule AnotherInvalidClient do
        def not_a_baml_client, do: :ok
      end

      assert {:error, reason} =
               FunctionIntrospector.validate_function_exists(AnotherInvalidClient, :TestFunction)

      assert reason =~ "does not implement __baml_src_path__"
    end
  end

  describe "validate_return_type_exists/2" do
    test "returns {:ok, module} for class return type when module exists" do
      return_type = {:class, "Reply"}

      assert {:ok, type_module} =
               FunctionIntrospector.validate_return_type_exists(BamlClient, return_type)

      assert type_module == AshBaml.Test.BamlClient.Types.Reply
    end

    test "returns {:ok, {:array, module}} for list of class return type" do
      return_type = {:list, {:class, "Reply"}}

      assert {:ok, {:array, type_module}} =
               FunctionIntrospector.validate_return_type_exists(BamlClient, return_type)

      assert type_module == AshBaml.Test.BamlClient.Types.Reply
    end

    test "returns {:ok, primitive} for primitive return types" do
      assert {:ok, :string} =
               FunctionIntrospector.validate_return_type_exists(BamlClient, {:primitive, :string})

      assert {:ok, :int} =
               FunctionIntrospector.validate_return_type_exists(BamlClient, {:primitive, :int})

      assert {:ok, :float} =
               FunctionIntrospector.validate_return_type_exists(BamlClient, {:primitive, :float})

      assert {:ok, :bool} =
               FunctionIntrospector.validate_return_type_exists(BamlClient, {:primitive, :bool})
    end

    test "returns error for class that doesn't have generated module" do
      return_type = {:class, "NonExistentClass"}

      assert {:error, reason} =
               FunctionIntrospector.validate_return_type_exists(BamlClient, return_type)

      assert reason =~ "Type module not found"
      assert reason =~ "NonExistentClass"
      assert reason =~ "mix ash_baml.gen.types"
    end

    test "returns error for list of class that doesn't exist" do
      return_type = {:list, {:class, "NonExistentClass"}}

      assert {:error, reason} =
               FunctionIntrospector.validate_return_type_exists(BamlClient, return_type)

      assert reason =~ "Type module not found"
      assert reason =~ "NonExistentClass"
    end

    test "returns error for unsupported return type" do
      return_type = {:unknown_type, "Something"}

      assert {:error, reason} =
               FunctionIntrospector.validate_return_type_exists(BamlClient, return_type)

      assert reason =~ "Unsupported return type"
    end
  end

  describe "map_params_to_arguments/1" do
    test "maps string parameter to :string argument" do
      params = %{"message" => {:primitive, :string}}
      arguments = FunctionIntrospector.map_params_to_arguments(params)

      assert [{:message, :string, [allow_nil?: false]}] = arguments
    end

    test "maps int parameter to :integer argument" do
      params = %{"age" => {:primitive, :int}}
      arguments = FunctionIntrospector.map_params_to_arguments(params)

      assert [{:age, :integer, [allow_nil?: false]}] = arguments
    end

    test "maps float parameter to :float argument" do
      params = %{"score" => {:primitive, :float}}
      arguments = FunctionIntrospector.map_params_to_arguments(params)

      assert [{:score, :float, [allow_nil?: false]}] = arguments
    end

    test "maps bool parameter to :boolean argument" do
      params = %{"active" => {:primitive, :bool}}
      arguments = FunctionIntrospector.map_params_to_arguments(params)

      assert [{:active, :boolean, [allow_nil?: false]}] = arguments
    end

    test "maps list parameter to {:array, inner_type} argument" do
      params = %{"tags" => {:list, {:primitive, :string}}}
      arguments = FunctionIntrospector.map_params_to_arguments(params)

      assert [{:tags, {:array, :string}, [allow_nil?: false]}] = arguments
    end

    test "maps class parameter to :map argument" do
      params = %{"user" => {:class, "User"}}
      arguments = FunctionIntrospector.map_params_to_arguments(params)

      assert [{:user, :map, [allow_nil?: false]}] = arguments
    end

    test "maps multiple parameters in order" do
      params = %{
        "name" => {:primitive, :string},
        "age" => {:primitive, :int},
        "active" => {:primitive, :bool}
      }

      arguments = FunctionIntrospector.map_params_to_arguments(params)

      assert length(arguments) == 3
      assert Enum.any?(arguments, fn {name, _, _} -> name == :name end)
      assert Enum.any?(arguments, fn {name, _, _} -> name == :age end)
      assert Enum.any?(arguments, fn {name, _, _} -> name == :active end)
    end

    test "all arguments have allow_nil?: false" do
      params = %{
        "name" => {:primitive, :string},
        "score" => {:primitive, :float}
      }

      arguments = FunctionIntrospector.map_params_to_arguments(params)

      assert Enum.all?(arguments, fn {_, _, opts} ->
               Keyword.get(opts, :allow_nil?) == false
             end)
    end

    test "maps unknown types to :any" do
      params = %{"unknown" => {:unknown_type, "something"}}
      arguments = FunctionIntrospector.map_params_to_arguments(params)

      assert [{:unknown, :any, [allow_nil?: false]}] = arguments
    end

    test "handles nested list types" do
      params = %{"matrix" => {:list, {:list, {:primitive, :int}}}}
      arguments = FunctionIntrospector.map_params_to_arguments(params)

      assert [{:matrix, {:array, {:array, :integer}}, [allow_nil?: false]}] = arguments
    end
  end
end
