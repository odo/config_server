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
        case System.cmd("git", ["pull"], cd: repo_path, env: env) do
        {_, 0} ->
            {:ok, commit_hash(repo_path)} 
        {_, exit_code} ->
            Logger.error("Failed to pull repo (exit code #{exit_code})")
            {:error, :failed_to_pull}
        end
      false ->
        Logger.info("Cloning config repo from #{repo_path} into #{repo_path}")
        case System.cmd("git", ["clone", repo_url, repo_path], env: env) do
        {_, 0} ->
            {:ok, commit_hash(repo_path)} 
        {_, exit_code} ->
            Logger.error("Failed to clone repo (exit code #{exit_code})")
            {:error, :failed_to_clone}
        end
    end
  end

  defp commit_hash(repo_path) do
    {commit_hash, 0} = System.cmd("git", ["log", "-1", "--format=%H"], cd: repo_path)
    commit_hash |> String.trim
  end
end
