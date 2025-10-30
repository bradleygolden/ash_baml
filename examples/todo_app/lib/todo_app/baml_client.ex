defmodule TodoApp.BamlClient do
  @moduledoc """
  BAML client for the TodoApp.

  This module provides functions for interacting with LLMs to extract,
  categorize, and summarize tasks using BAML-defined schemas.
  """

  use BamlElixir.Client,
    baml_src: "baml_src"

  @doc """
  Returns the path to the BAML source directory.

  This function is used by ash_baml.gen.types Mix task to locate BAML schema files.
  """
  def __baml_src_path__ do
    Path.join(File.cwd!(), "baml_src")
  end
end
