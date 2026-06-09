defmodule ConfigServer do
  @moduledoc """
  This module implements a GenServer that monitors a git repository.
  The content of the repository is parsed and changes are handed to a callback.
  """
  use GenServer

  alias ConfigServer.{Parser, Git}

  defstruct [
    :repo_url,
    :git_ssh_command,
    :repo_path,
    :config,
    :commit_hash,
    :pull_interval_ms,
    :state_change_fun,
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
      git_ssh_command: String.t() | nil,
      repo_path: String.t(),
      pull_interval_ms: integer(),
      state_change_fun: nil | fun()
    }) :: {:ok, pid()}
  def start_link(%{repo_url: repo_url, repo_path: repo_path, git_ssh_command: git_ssh_command, pull_interval_ms: pull_interval_ms, state_change_fun: state_change_fun} = args)
    when is_binary(repo_url) and is_binary(repo_path) and
         (is_binary(git_ssh_command) or is_nil(git_ssh_command)) and
         is_integer(pull_interval_ms) and pull_interval_ms > 0 and
         (is_nil(state_change_fun) or is_function(state_change_fun) or is_tuple(state_change_fun)) do
    {:ok, _} = GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(%{repo_url: repo_url, repo_path: repo_path, git_ssh_command: git_ssh_command, pull_interval_ms: pull_interval_ms, state_change_fun: state_change_fun})
    when is_binary(repo_url) and is_binary(repo_path) and
         (is_binary(git_ssh_command) or is_nil(git_ssh_command)) and
         is_integer(pull_interval_ms) and pull_interval_ms > 0 and
         (is_nil(state_change_fun) or is_function(state_change_fun) or is_tuple(state_change_fun)) do
    initial_state = %ConfigServer{
      repo_url: repo_url,
      git_ssh_command: git_ssh_command,
      repo_path: repo_path,
      pull_interval_ms: pull_interval_ms,
      state_change_fun: state_change_fun,
      ets_table: :ets.new(__MODULE__, [:set, :protected, :named_table, {:read_concurrency, true}])
    }
    schedule_next_pull(0)
    {:ok, initial_state}
  end

  @impl true
  def handle_info(
    :pull_configs,
    %ConfigServer{
      repo_url: repo_url, git_ssh_command: git_ssh_command, repo_path: repo_path,
      pull_interval_ms: pull_interval_ms, state_change_fun: state_change_fun} = state
  ) do
    schedule_next_pull(pull_interval_ms)
    Git.refresh(repo_url, repo_path, git_ssh_command)
    next_state =
      %ConfigServer{state | 
        config:      Parser.parse_directory(repo_path), 
        commit_hash: Git.commit_hash(repo_path) 
      }
    :ets.insert(__MODULE__, {:config, next_state.config})
    if state_change_fun != nil && state.commit_hash != next_state.commit_hash do
      execute(state_change_fun, state.config, next_state.config)
    end
    {:noreply, next_state}
  end

  defp schedule_next_pull(delay) when is_integer(delay) do
    Process.send_after(self(), :pull_configs, delay, [])
  end

  def get_application_env() do
    %{
      repo_url: Application.get_env(:config_server, :repo_url), 
      git_ssh_command: Application.get_env(:config_server, :git_ssh_command), 
      repo_path: Application.get_env(:config_server, :repo_path),
      pull_interval_ms: Application.get_env(:config_server, :pull_interval_ms), 
      state_change_fun: Application.get_env(:config_server, :state_change_fun)
    }
  end
  
  defp execute({module, function}, old_config, new_config) do
      spawn(fn() -> apply(module, function, [old_config, new_config]) end)
  end

  defp execute(state_change_fun, old_config, new_config) when is_function(state_change_fun) do
      spawn(fn() -> state_change_fun.(old_config, new_config) end)
  end

end
