defmodule ConfigServer.Git do

  require Logger

  def refresh(repo_url, repo_path) do 
    if !File.exists?(repo_path) do
        Logger.info("Setting up folder for config repo")
        {_, 0} = System.cmd("mkdir", ["-p", repo_path])
      end

      git_path = Path.join(repo_path, ".git")
      case File.exists?(git_path) do
        true ->
          {_, 0} = System.cmd("git", ["pull"], cd: repo_path)
        false ->
          Logger.info("Cloning config repo")
          {_, 0} = System.cmd("git", ["clone", repo_url, repo_path])
      end
  end

  def commit_hash(repo_path) do
    {commit_hash, 0} = System.cmd("git", ["log", "-1", "--format=%H"], cd: repo_path)
    commit_hash
  end
end
