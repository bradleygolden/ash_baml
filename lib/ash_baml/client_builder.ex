defmodule AshBaml.ClientBuilder do
  @moduledoc false

  alias AshBaml.ClientBuilder.Server

  @type client_identifier :: atom()
  @type client_config :: [{client_identifier(), {module(), keyword()}}]

  @spec ensure_configured_client_module(client_identifier(), client_config() | nil) ::
          {:ok, module()} | {:error, String.t()}
  def ensure_configured_client_module(identifier, clients \\ nil) do
    clients = clients || Application.get_env(:ash_baml, :clients, [])

    case Keyword.get(clients, identifier) do
      nil ->
        {:error, client_not_configured_error(identifier, clients)}

      {module_name, opts} ->
        baml_src = Keyword.get(opts, :baml_src)

        case {Code.ensure_loaded?(module_name), baml_src} do
          {true, nil} ->
            {:ok, module_name}

          {_, path} when is_binary(path) or is_list(path) ->
            with :ok <- ensure_client_module(module_name, path) do
              {:ok, module_name}
            end

          {true, _} ->
            {:ok, module_name}

          _ ->
            {:error,
             "BAML client #{inspect(identifier)} is configured to use #{inspect(module_name)} but no :baml_src was provided. Provide :baml_src or predefine #{inspect(module_name)} manually."}
        end
    end
  end

  @spec ensure_client_module(module(), String.t()) :: :ok | {:error, String.t()}
  def ensure_client_module(module_name, baml_src) do
    ensure_server_started()
    Server.ensure_module(module_name, baml_src)
  end

  defp ensure_server_started do
    case GenServer.whereis(Server) do
      nil ->
        case Server.start_link([]) do
          {:ok, _pid} -> :ok
          {:error, {:already_started, _pid}} -> :ok
        end

      _pid ->
        :ok
    end
  end

  defp client_not_configured_error(identifier, available_clients) do
    available =
      case available_clients do
        [] -> "No clients configured."
        clients -> "Available: #{inspect(Keyword.keys(clients))}."
      end

    "BAML client :#{identifier} not found in application config. #{available} Add to config/config.exs: config :ash_baml, clients: [#{identifier}: {MyApp.BamlClient, baml_src: \"baml_src\"}]"
  end
end
