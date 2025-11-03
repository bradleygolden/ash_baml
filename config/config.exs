import Config

# Force build baml_elixir from source to use the custom fork
config :rustler_precompiled, :force_build, baml_elixir: true

env_config = "#{config_env()}.exs"

if File.exists?(Path.join(__DIR__, env_config)) do
  import_config env_config
end
