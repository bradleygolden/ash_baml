defmodule AshBaml.CodeWriterTest do
  use ExUnit.Case, async: true

  alias AshBaml.CodeWriter

  setup do
    tmp_dir = "tmp/code_writer_test_#{System.unique_integer([:positive])}"
    File.rm_rf!(tmp_dir)
    File.mkdir_p!(tmp_dir)

    on_exit(fn ->
      File.rm_rf!(tmp_dir)
    end)

    {:ok, tmp_dir: tmp_dir}
  end

  describe "write_module/3" do
    test "writes formatted module code to correct path", %{tmp_dir: tmp_dir} do
      module_code = """
      defmodule TestModule do
        def hello, do: :world
      end
      """

      assert {:ok, file_path} = CodeWriter.write_module(TestModule, module_code, tmp_dir)
      assert file_path == Path.join(tmp_dir, "test_module.ex")
      assert File.exists?(file_path)

      content = File.read!(file_path)
      assert content =~ "defmodule TestModule do"
      assert content =~ "def hello, do: :world"
    end

    test "creates nested directories for namespaced modules", %{tmp_dir: tmp_dir} do
      module_code = """
      defmodule MyApp.Nested.Module do
        def test, do: :ok
      end
      """

      assert {:ok, file_path} =
               CodeWriter.write_module(MyApp.Nested.Module, module_code, tmp_dir)

      assert file_path == Path.join([tmp_dir, "my_app", "nested", "module.ex"])
      assert File.exists?(file_path)
    end

    test "formats code using Code.format_string!", %{tmp_dir: tmp_dir} do
      unformatted_code = """
      defmodule   UnformattedModule   do
      def    poorly_formatted,    do:    :value
      end
      """

      assert {:ok, file_path} =
               CodeWriter.write_module(UnformattedModule, unformatted_code, tmp_dir)

      content = File.read!(file_path)
      assert content =~ "defmodule UnformattedModule do"
      refute content =~ "UnformattedModule   do"
    end

    test "returns error when code formatting fails", %{tmp_dir: tmp_dir} do
      invalid_code = "defmodule Invalid do\n  def foo do\nend"

      assert {:error, error_msg} = CodeWriter.write_module(InvalidModule, invalid_code, tmp_dir)
      assert error_msg =~ "Failed to format code"
    end

    test "overwrites existing file with same module name", %{tmp_dir: tmp_dir} do
      module_code_v1 = """
      defmodule OverwriteTest do
        def version, do: 1
      end
      """

      module_code_v2 = """
      defmodule OverwriteTest do
        def version, do: 2
      end
      """

      assert {:ok, file_path} = CodeWriter.write_module(OverwriteTest, module_code_v1, tmp_dir)
      content_v1 = File.read!(file_path)
      assert content_v1 =~ "def version, do: 1"

      assert {:ok, ^file_path} = CodeWriter.write_module(OverwriteTest, module_code_v2, tmp_dir)
      content_v2 = File.read!(file_path)
      assert content_v2 =~ "def version, do: 2"
      refute content_v2 =~ "def version, do: 1"
    end
  end

  describe "module_to_path/2" do
    test "converts simple module name to path" do
      assert CodeWriter.module_to_path(SimpleModule, "lib") == "lib/simple_module.ex"
    end

    test "converts nested module names to nested paths" do
      assert CodeWriter.module_to_path(MyApp.User, "lib") == "lib/my_app/user.ex"

      assert CodeWriter.module_to_path(MyApp.Nested.Deep.Module, "lib") ==
               "lib/my_app/nested/deep/module.ex"
    end

    test "handles different base paths" do
      assert CodeWriter.module_to_path(TestModule, "test/support") ==
               "test/support/test_module.ex"

      assert CodeWriter.module_to_path(Foo.Bar, "custom/path") == "custom/path/foo/bar.ex"
    end

    test "converts CamelCase to snake_case" do
      assert CodeWriter.module_to_path(MyHTTPClient, "lib") == "lib/my_http_client.ex"
      assert CodeWriter.module_to_path(XMLParser, "lib") == "lib/xml_parser.ex"
    end
  end

  describe "ensure_types_directory/1" do
    test "creates directory and README when neither exist", %{tmp_dir: tmp_dir} do
      types_dir = Path.join(tmp_dir, "types")

      assert :ok = CodeWriter.ensure_types_directory(types_dir)
      assert File.dir?(types_dir)

      readme_path = Path.join(types_dir, "README.md")
      assert File.exists?(readme_path)

      content = File.read!(readme_path)
      assert content =~ "Generated Ash Types from BAML"
      assert content =~ "Do not edit these files directly"
    end

    test "creates only directory when README already exists", %{tmp_dir: tmp_dir} do
      types_dir = Path.join(tmp_dir, "types_with_readme")
      File.mkdir_p!(types_dir)

      existing_readme_path = Path.join(types_dir, "README.md")
      existing_content = "# Custom README\nDo not overwrite me"
      File.write!(existing_readme_path, existing_content)

      assert :ok = CodeWriter.ensure_types_directory(types_dir)
      assert File.dir?(types_dir)

      content = File.read!(existing_readme_path)
      assert content == existing_content
    end

    test "succeeds when directory and README both already exist", %{tmp_dir: tmp_dir} do
      types_dir = Path.join(tmp_dir, "existing_types")
      File.mkdir_p!(types_dir)
      readme_path = Path.join(types_dir, "README.md")
      File.write!(readme_path, "# Existing README")

      assert :ok = CodeWriter.ensure_types_directory(types_dir)
      assert File.dir?(types_dir)
      assert File.exists?(readme_path)
    end

    test "creates nested directory structure", %{tmp_dir: tmp_dir} do
      types_dir = Path.join([tmp_dir, "deeply", "nested", "types"])

      assert :ok = CodeWriter.ensure_types_directory(types_dir)
      assert File.dir?(types_dir)
      assert File.exists?(Path.join(types_dir, "README.md"))
    end
  end
end
