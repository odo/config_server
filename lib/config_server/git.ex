defmodule ConfigServer.Git do

  require Logger

  def refresh(repo_url, repo_path, git_ssh_command) do 
    if !File.exists?(repo_path) do
      Logger.info("Setting up folder for config repo")
      {_, 0} = System.cmd("mkdir", ["-p", repo_path])
    end

    env =
    case git_ssh_command do
        nil -> []
        command -> [{"GIT_SSH_COMMAND", command}]
      end

    git_path = Path.join(repo_path, ".git")
    case File.exists?(git_path) do
      true ->
        {_, 0} = System.cmd("git", ["pull"], cd: repo_path, env: env)
      false ->
        Logger.info("Cloning config repo")
        {_, 0} = System.cmd("git", ["clone", repo_url, repo_path], env: env)
    end
  end

  def commit_hash(repo_path) do
    {commit_hash, 0} = System.cmd("git", ["log", "-1", "--format=%H"], cd: repo_path)
    commit_hash |> String.trim
  end
end
