defmodule ConfigServer do
  use GenServer

  alias ConfigServer.Utils

  require Logger

  defstruct [
    :repo_url,
    :github_token,
    :repo_path,
    :config,
    :commit_hash,
    :pull_interval_ms
  ]

  # API
  def config() do
    GenServer.call(__MODULE__, :config)
  end

  # Server functions
  @spec start_link(%{
      repo_url: String.t(),
      github_token: String.t(),
      repo_path: String.t(),
      pull_interval_ms: integer(),
    }) :: {:ok, pid()}
  def start_link(%{repo_url: _, github_token: _, repo_path: _, pull_interval_ms: _}) do
    {:ok, _} = GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(%{repo_url: repo_url, github_token: github_token, repo_path: repo_path, pull_interval_ms: pull_interval_ms})
    when is_binary(repo_url) and is_binary(github_token) and is_binary(repo_path) and is_integer(pull_interval_ms) do
    initial_state = %ConfigServer{
      repo_url: repo_url,
      github_token: github_token,
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
    pull_configs_from_repo(state)

    {:noreply, state}
  end

  @impl true
  def handle_cast(:parse_configs, state) do
    {:noreply, parse_configs_from_filesystem(state)}
  end

  defp parse_configs_from_filesystem(%ConfigServer{repo_path: repo_path} = state) do
    config = Utils.parse_directory(repo_path)
    {commit_hash, 0} = System.cmd("git", ["log", "-1", "--format=%H"], cd: repo_path)

    %ConfigServer{state | 
      config: config,
      commit_hash: commit_hash
    }
  end

  defp pull_configs_from_repo(%ConfigServer{repo_path: repo_path, github_token: github_token, repo_url: repo_url}) do
    config_server = self()
    spawn(fn () ->
      if !File.exists?(repo_path) do
        Logger.info("Setting up folder for config repo")
        {_, 0} = System.cmd("mkdir", ["-p", repo_path])
      end

      git_path = Path.join(repo_path, ".git")
      case !File.exists?(git_path) do
        true ->
          Logger.info("Pulling config repo")
          {_, 0} = System.cmd("git", ["pull"], cd: repo_path)
        false ->
          Logger.info("Cloning config repo")
          {_, 0} = System.cmd("git", ["clone", "https://#{github_token}@" <> repo_url, repo_path])
      end

      GenServer.cast(config_server, :parse_configs)
    end)
  end

  def schedule_next_pull(%ConfigServer{pull_interval_ms: pull_interval_ms}) do
    Process.send_after(self(), :pull_configs, pull_interval_ms, [])
  end

end
