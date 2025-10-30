defmodule AshBaml.TypeGenerationTest do
  use ExUnit.Case, async: true

  alias AshBaml.{BamlParser, CodeWriter, TypeGenerator}

  @fixtures_path "test/support/fixtures/baml_src"
  @tmp_output "tmp/test_generation"

  setup do
    File.rm_rf!(@tmp_output)
    :ok
  end

  describe "end-to-end type generation" do
    test "generates valid TypedStruct modules from BAML classes" do
      {:ok, schema} = BamlParser.parse_schema(@fixtures_path)
      classes = BamlParser.extract_classes(schema)

      assert Map.has_key?(classes, "WeatherTool")
      weather_tool = classes["WeatherTool"]

      code =
        TypeGenerator.generate_typed_struct(
          "WeatherTool",
          weather_tool,
          Test.Types.WeatherTool,
          source_file: "test.baml"
        )

      assert code =~ "defmodule Test.Types.WeatherTool"
      assert code =~ "use Ash.TypedStruct"
      assert code =~ "field :city, :string"
      assert code =~ "field :units, :string"
      assert code =~ "Generated from BAML class: WeatherTool"

      assert is_list(Code.format_string!(code))
    end

    test "generates correct file paths for modules" do
      path = CodeWriter.module_to_path(MyApp.BamlClient.Types.WeatherTool, "lib")
      assert path == "lib/my_app/baml_client/types/weather_tool.ex"
    end

    test "writes modules to correct file locations" do
      module_code = """
      defmodule Test.GeneratedType do
        def test, do: :ok
      end
      """

      {:ok, file_path} = CodeWriter.write_module(Test.GeneratedType, module_code, @tmp_output)

      assert File.exists?(file_path)
      assert file_path == Path.join([@tmp_output, "test", "generated_type.ex"])

      content = File.read!(file_path)
      assert content =~ "defmodule Test.GeneratedType"
    end

    test "creates README in types directory" do
      types_dir = Path.join(@tmp_output, "types")
      CodeWriter.ensure_types_directory(types_dir)

      readme_path = Path.join(types_dir, "README.md")
      assert File.exists?(readme_path)

      content = File.read!(readme_path)
      assert content =~ "Generated Ash Types from BAML"
      assert content =~ "Do not edit these files directly"
    end
  end

  describe "BamlParser" do
    test "extracts classes from BAML schema" do
      {:ok, schema} = BamlParser.parse_schema(@fixtures_path)
      classes = BamlParser.extract_classes(schema)

      assert is_map(classes)
      assert Map.has_key?(classes, "WeatherTool")
      assert Map.has_key?(classes, "CalculatorTool")
      assert Map.has_key?(classes, "Reply")
    end

    test "gets BAML path from client module" do
      {:ok, path} = BamlParser.get_baml_path(AshBaml.Test.BamlClient)
      assert String.ends_with?(path, "fixtures/baml_src")
    end
  end

  describe "TypeGenerator" do
    test "handles optional fields correctly" do
      class_def = %{
        "fields" => %{
          "required_field" => {:primitive, :string},
          "optional_field" => {:optional, {:primitive, :string}}
        }
      }

      code =
        TypeGenerator.generate_typed_struct(
          "TestClass",
          class_def,
          Test.Types.TestClass
        )

      assert code =~ "field :required_field, :string, allow_nil?: false"
      assert code =~ "field :optional_field, :string, allow_nil?: true"
    end

    test "handles array fields correctly" do
      class_def = %{
        "fields" => %{
          "items" => {:list, {:primitive, :string}}
        }
      }

      code =
        TypeGenerator.generate_typed_struct(
          "Container",
          class_def,
          Test.Types.Container
        )

      assert code =~ "field :items, {:array, :string}"
    end

    test "converts PascalCase to snake_case for field names" do
      class_def = %{
        "fields" => %{
          "SomeField" => {:primitive, :string}
        }
      }

      code =
        TypeGenerator.generate_typed_struct(
          "TestClass",
          class_def,
          Test.Types.TestClass
        )

      assert code =~ "field :some_field, :string"
    end
  end
end
