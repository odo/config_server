defmodule ConfigServer do
  @moduledoc """
  This module implements a GenServer that monitors a git repository.
  The content of the repository is parsed and changes are handed to a callback.
  """
  use GenServer

  alias ConfigServer.{Parser, Git}

  defstruct [
    :repo_url,
    :repo_path,
    :config,
    :commit_hash,
    :pull_interval_ms,
    :state_change_fun
  ]

  # API
  @doc """
  Retrieve the current config.
  """
  def config() do
    GenServer.call(__MODULE__, :config)
  end

  # Server functions
  @spec start_link([]) :: {:ok, pid()}
  def start_link([]) do
    get_application_env() |> start_link()
  end

  @spec start_link(%{
      repo_url: String.t(),
      repo_path: String.t(),
      pull_interval_ms: integer(),
      state_change_fun: nil | fun()
    }) :: {:ok, pid()}
  def start_link(%{repo_url: repo_url, repo_path: repo_path, pull_interval_ms: pull_interval_ms, state_change_fun: state_change_fun} = args)
    when is_binary(repo_url) and is_binary(repo_path) and
         is_integer(pull_interval_ms) and pull_interval_ms > 0 and
         (is_nil(state_change_fun) or is_function(state_change_fun)) do
    {:ok, _} = GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(%{repo_url: repo_url, repo_path: repo_path, pull_interval_ms: pull_interval_ms, state_change_fun: state_change_fun})
    when is_binary(repo_url) and is_binary(repo_path) and
         is_integer(pull_interval_ms) and pull_interval_ms > 0 and
         (is_nil(state_change_fun) or is_function(state_change_fun)) do
    initial_state = %ConfigServer{
      repo_url: repo_url,
      repo_path: repo_path,
      pull_interval_ms: pull_interval_ms,
      state_change_fun: state_change_fun
    }
    schedule_next_pull(initial_state)
    pull_configs_from_repo(initial_state)
    {:ok, parse_configs_from_filesystem(initial_state)}
  end

  @impl true
  def handle_call(:config, _from, %{config: config} = state) do
    {:reply, config, state}
  end

  @impl true
  def handle_info(:pull_configs, state) do
    schedule_next_pull(state)
    spawn(fn() -> pull_configs_from_repo(state) end)
    {:noreply, state}
  end

  @impl true
  def handle_cast(:parse_configs, state) do
    {:noreply, parse_configs_from_filesystem(state)}
  end

  defp parse_configs_from_filesystem(%ConfigServer{repo_path: repo_path, state_change_fun: state_change_fun} = state) do
    next_config = Parser.parse_directory(repo_path)
    next_commit_hash = Git.commit_hash(repo_path)

    next_state =
      %ConfigServer{state | 
        config:      next_config, 
        commit_hash: next_commit_hash 
      }

    if is_function(state_change_fun) && state.commit_hash != next_state.commit_hash do
      spawn(fn() -> state_change_fun.(state.config, next_state.config) end)
    end

    next_state
  end

  defp pull_configs_from_repo(%ConfigServer{repo_path: repo_path, repo_url: repo_url}) do
    Git.refresh(repo_url, repo_path)
    GenServer.cast(__MODULE__, :parse_configs)
  end

  defp schedule_next_pull(%ConfigServer{pull_interval_ms: pull_interval_ms}) do
    Process.send_after(self(), :pull_configs, pull_interval_ms, [])
  end

  def get_application_env() do
    %{
      repo_url: Application.get_env(:config_server, :repo_url), 
      repo_path: Application.get_env(:config_server, :repo_path),
      pull_interval_ms: Application.get_env(:config_server, :pull_interval_ms), 
      state_change_fun: Application.get_env(:config_server, :state_change_fun)
    }
  end


end
