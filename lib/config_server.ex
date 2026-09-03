defmodule ConfigServer do
  @moduledoc """
  This module implements a GenServer that monitors a git repository.
  The content of the repository is parsed and changes are handed to a callback.
  """

  require Logger
  use GenServer

  alias ConfigServer.{Parser, Git}

  defstruct [
    :repo_url,
    :git_ssh_command,
    :repo_path,
    :branch,
    :config,
    :commit_hash,
    :pull_interval_ms,
    :state_change_fun,
    :parsing_fun,
    :ets_table
  ]

  # API
  @doc """
  Retrieve the current config.
  """
  def config() do
    [{:config, config}] = :ets.lookup(__MODULE__, :config)
    config
  end

  # Server functions
  @spec start_link([]) :: {:ok, pid()}
  def start_link([]) do
    get_application_env() |> start_link()
  end

  @spec start_link(%{
      repo_url: String.t(),
      branch: String.t() | nil,
      git_ssh_command: String.t() | nil,
      repo_path: String.t(),
      pull_interval_ms: integer(),
      state_change_fun: nil | fun() | {atom(), atom()},
      parsing_fun: nil | fun() | {atom(), atom()}
    }) :: {:ok, pid()}
  def start_link(%{repo_url: repo_url, repo_path: repo_path, branch: branch, git_ssh_command: git_ssh_command, pull_interval_ms: pull_interval_ms, state_change_fun: state_change_fun, parsing_fun: parsing_fun} = args)
    when is_binary(repo_url) and is_binary(repo_path) and
         (is_binary(branch) or is_nil(branch)) and
         (is_binary(git_ssh_command) or is_nil(git_ssh_command)) and
         is_integer(pull_interval_ms) and pull_interval_ms > 0 and
         (is_nil(state_change_fun) or is_function(state_change_fun) or is_tuple(state_change_fun) and
         (is_nil(parsing_fun) or is_function(parsing_fun) or is_tuple(parsing_fun))) do
    {:ok, _} = GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(%{repo_url: repo_url, repo_path: repo_path, branch: branch, git_ssh_command: git_ssh_command, pull_interval_ms: pull_interval_ms, state_change_fun: state_change_fun, parsing_fun: parsing_fun})
    when is_binary(repo_url) and is_binary(repo_path) and
         (is_binary(branch) or is_nil(branch)) and
         (is_binary(git_ssh_command) or is_nil(git_ssh_command)) and
         is_integer(pull_interval_ms) and pull_interval_ms > 0 and
         (is_nil(state_change_fun) or is_function(state_change_fun) or is_tuple(state_change_fun) and
         (is_nil(parsing_fun) or is_function(parsing_fun) or is_tuple(parsing_fun))) do
    {:ok, commit_hash} = Git.ensure_checkout(repo_url, repo_path, git_ssh_command)
    branch = branch || Git.default_branch(repo_path, git_ssh_command)
    initial_state = %ConfigServer{
      repo_url: repo_url,
      branch: branch,
      commit_hash: commit_hash,
      git_ssh_command: git_ssh_command,
      repo_path: repo_path,
      pull_interval_ms: pull_interval_ms,
      state_change_fun: state_change_fun || fn(_, _) -> :ok end,
      parsing_fun: parsing_fun || {Parser, :parse_directory},
      ets_table: :ets.new(__MODULE__, [:set, :protected, :named_table, {:read_concurrency, true}])
    }
    GenServer.cast(__MODULE__, :initial_load)
    {:ok, initial_state}
  end

  @impl true
  def handle_cast( :initial_load, %ConfigServer{repo_path: repo_path, state_change_fun: state_change_fun, parsing_fun: parsing_fun, commit_hash: commit_hash} = state) do
    case execute(state_change_fun, nil, repo_path, parsing_fun) do
      {:ok, next_config} ->
        next_state = %ConfigServer{state | config: next_config}
        :ets.insert(__MODULE__, {:config, next_state.config})
        schedule_next_pull(0)
        {:noreply, next_state}
      {:error, error} ->
        Logger.error("Config callback returned error for #{commit_hash} (no known state to roll back to) : #{inspect({:error, error})}")
        throw({:error, :no_known_good_state})
    end
  end

  @impl true
  def handle_info(
    :pull_configs,
    %ConfigServer{
      repo_url: repo_url, branch: branch, git_ssh_command: git_ssh_command, repo_path: repo_path,
      pull_interval_ms: pull_interval_ms, state_change_fun: state_change_fun, parsing_fun: parsing_fun, commit_hash: commit_hash} = state
  ) do
    schedule_next_pull(pull_interval_ms)
    case Git.refresh(repo_path, branch, git_ssh_command) do
      {:ok, ^commit_hash} ->
        {:noreply, state}
      {:ok, next_commit_hash} ->
        Logger.info("Loading new config from #{repo_url}: #{next_commit_hash}")
        case execute(state_change_fun, state.config, repo_path, parsing_fun) do
          {:ok, next_config} ->
            next_state = %ConfigServer{state | config: next_config, commit_hash: next_commit_hash }
            :ets.insert(__MODULE__, {:config, next_config})
            {:noreply, next_state}
          {:error, error} ->
            case commit_hash do
              nil ->
                Logger.error("Config callback returned error for #{next_commit_hash} (no known state to roll back to) : #{inspect({:error, error})}")
                throw({:error, :no_known_good_state})
              _ ->
                Logger.error("Config callback returned error for #{next_commit_hash} (rolling back to #{commit_hash}) : #{inspect({:error, error})}")
                {:ok, ^commit_hash} = Git.checkout(commit_hash, repo_path, git_ssh_command)
                {:noreply, state}
            end
        end
      {:error, error} ->
        Logger.warning("Failed to pull repo #{repo_url}: #{inspect(error)}")
        {:noreply, state}
    end
  end

  defp schedule_next_pull(delay) when is_integer(delay) do
    Process.send_after(self(), :pull_configs, delay, [])
  end

  def get_application_env() do
    %{
      repo_url: Application.get_env(:config_server, :repo_url), 
      branch: Application.get_env(:config_server, :branch), 
      git_ssh_command: Application.get_env(:config_server, :git_ssh_command), 
      repo_path: Application.get_env(:config_server, :repo_path),
      pull_interval_ms: Application.get_env(:config_server, :pull_interval_ms), 
      state_change_fun: Application.get_env(:config_server, :state_change_fun),
      parsing_fun: Application.get_env(:config_server, :parsing_fun)
    }
    |> validate_env([:repo_url, :repo_path, :pull_interval_ms])
  end
 
  defp validate_env(map, keys) do
    case Enum.all?(keys, &(Map.get(map, &1) != nil)) do
      true -> map
      false -> throw({:error, {:required_config, keys}})
    end
  end

  defp execute(state_change_fun, old_config, repo_path, parsing_fun) do
    case parse(repo_path, parsing_fun) do
      {:ok, new_config} ->
        case do_execute(state_change_fun, old_config, new_config) do
          :error -> {:error, :unknown}
          {:error, error} -> {:error, error}
          _ -> {:ok, new_config}
        end
      {:error, error} -> {:error, error}
      unexpected -> {:error, {:unexpected_value, unexpected}}
    end
  rescue
    error -> {:error, error}
  end

  defp do_execute({module, function}, old_config, new_config) do
    apply(module, function, [old_config, new_config])
  end
  defp do_execute(state_change_fun, old_config, new_config) when is_function(state_change_fun) do
      state_change_fun.(old_config, new_config)
  end

  defp parse(repo_path, {module, function}) do
    :erlang.apply(module, function, [repo_path])
  end
  defp parse(repo_path, parsing_fun) when is_function(parsing_fun) do
    parsing_fun.(repo_path)
  end

end
