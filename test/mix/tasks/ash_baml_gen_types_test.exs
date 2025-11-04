defmodule Mix.Tasks.AshBaml.Gen.TypesTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.AshBaml.Gen.Types

  setup do
    tmp_dir =
      Path.join([
        System.tmp_dir!(),
        "ash_baml_gen_types_test_#{System.unique_integer([:positive])}"
      ])

    on_exit(fn ->
      if File.exists?(tmp_dir) do
        File.rm_rf!(tmp_dir)
      end
    end)

    %{tmp_dir: tmp_dir}
  end

  describe "run/1 with invalid arguments" do
    test "shows error when no arguments provided" do
      stderr =
        capture_io(:stderr, fn ->
          capture_io(fn ->
            Types.run([])
          end)
        end)

      assert stderr =~ "Usage: mix ash_baml.gen.types <ClientModule>"
    end

    test "shows error when too many arguments provided" do
      stderr =
        capture_io(:stderr, fn ->
          capture_io(fn ->
            Types.run(["Module1", "Module2"])
          end)
        end)

      assert stderr =~ "Usage: mix ash_baml.gen.types <ClientModule>"
    end
  end

  describe "run/1 with invalid client module" do
    test "shows error when module does not implement __baml_src_path__/0" do
      stderr =
        capture_io(:stderr, fn ->
          capture_io(fn ->
            Types.run(["NonExistent.Module"])
          end)
        end)

      assert stderr =~ "does not implement __baml_src_path__/0"
    end
  end

  describe "run/1 with valid client - dry run mode" do
    test "shows what would be generated without writing files", %{tmp_dir: tmp_dir} do
      output =
        capture_io(fn ->
          Types.run(["AshBaml.Test.BamlClient", "--dry-run", "--output-dir", tmp_dir])
        end)

      assert output =~ "Generating types for AshBaml.Test.BamlClient"
      assert output =~ "Classes:"
      assert output =~ "Enums:"
      assert output =~ "Dry run complete. No files were written"

      refute File.exists?(tmp_dir)
    end

    test "accepts -d alias for --dry-run", %{tmp_dir: tmp_dir} do
      output =
        capture_io(fn ->
          Types.run(["AshBaml.Test.BamlClient", "-d", "--output-dir", tmp_dir])
        end)

      assert output =~ "Dry run complete"
    end
  end

  describe "run/1 with valid client - verbose mode" do
    test "shows detailed output during generation", %{tmp_dir: tmp_dir} do
      output =
        capture_io(fn ->
          Types.run([
            "AshBaml.Test.BamlClient",
            "--verbose",
            "--dry-run",
            "--output-dir",
            tmp_dir
          ])
        end)

      assert output =~ "Loading BAML configuration from"
      assert output =~ "BAML source path:"
      assert output =~ "Parsing BAML schema..."
    end

    test "accepts -v alias for --verbose", %{tmp_dir: tmp_dir} do
      output =
        capture_io(fn ->
          Types.run(["AshBaml.Test.BamlClient", "-v", "--dry-run", "--output-dir", tmp_dir])
        end)

      assert output =~ "Loading BAML configuration from"
    end
  end

  describe "run/1 with valid client - file generation" do
    test "generates type files successfully", %{tmp_dir: tmp_dir} do
      output =
        capture_io(fn ->
          Types.run(["AshBaml.Test.BamlClient", "--output-dir", tmp_dir])
        end)

      assert output =~ "Generating types for AshBaml.Test.BamlClient"
      assert output =~ "Successfully generated"
      assert output =~ "type modules"
      assert output =~ "Next steps:"

      types_dir =
        Path.join([
          tmp_dir,
          "ash_baml",
          "test",
          "baml_client",
          "types"
        ])

      assert File.exists?(types_dir)
      assert File.exists?(Path.join(types_dir, "README.md"))

      files = File.ls!(types_dir)
      assert Enum.any?(files, &String.ends_with?(&1, ".ex"))
    end

    test "accepts -o alias for --output-dir", %{tmp_dir: tmp_dir} do
      output =
        capture_io(fn ->
          Types.run(["AshBaml.Test.BamlClient", "-o", tmp_dir])
        end)

      assert output =~ "Successfully generated"
    end

    test "shows individual file paths when writing", %{tmp_dir: tmp_dir} do
      output =
        capture_io(fn ->
          Types.run(["AshBaml.Test.BamlClient", "--output-dir", tmp_dir])
        end)

      assert output =~ "✓"
      assert output =~ ".ex"
    end
  end

  describe "run/1 with verbose and file generation" do
    test "shows both verbose logs and file paths", %{tmp_dir: tmp_dir} do
      output =
        capture_io(fn ->
          Types.run(["AshBaml.Test.BamlClient", "--verbose", "--output-dir", tmp_dir])
        end)

      assert output =~ "Loading BAML configuration from"
      assert output =~ "Generating TypedStruct:"
      assert output =~ "✓"
    end
  end
end
