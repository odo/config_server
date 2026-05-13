defmodule ConfigServer do
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
  def config() do
    GenServer.call(__MODULE__, :config)
  end

  # Server functions
  @spec start_link(%{
      repo_url: String.t(),
      repo_path: String.t(),
      pull_interval_ms: integer(),
      state_change_fun: nil | fun()
    }) :: {:ok, pid()}
  def start_link(%{repo_url: _, repo_path: _, pull_interval_ms: _, state_change_fun: _} = args) do
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
      pull_interval_ms: pull_interval_ms
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
    next_state =
      %ConfigServer{state | 
        config:      Parser.parse_directory(repo_path),
        commit_hash: Git.commit_hash(repo_path)
      }

    if is_function(state_change_fun) && state.commit_hash != next_state.commit_hash do
      spawn(fn() -> state_change_fun.(state, next_state) end)
    end

    next_state
  end

  defp pull_configs_from_repo(%ConfigServer{repo_path: repo_path, repo_url: repo_url}) do
    Git.refresh(repo_url, repo_path)
    GenServer.cast(__MODULE__, :parse_configs)
  end

  def schedule_next_pull(%ConfigServer{pull_interval_ms: pull_interval_ms}) do
    Process.send_after(self(), :pull_configs, pull_interval_ms, [])
  end

end
