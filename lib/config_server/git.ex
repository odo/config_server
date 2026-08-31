defmodule ConfigServer.Git do

  require Logger

  def refresh(repo_path, branch, git_ssh_command) do 
    {:ok, _} = checkout(branch, repo_path, git_ssh_command)
    case System.cmd("git", ["pull"], cd: repo_path, env: env(git_ssh_command)) do
    {_, 0} ->
        {:ok, commit_hash(repo_path)} 
    {_, exit_code} ->
        Logger.error("Failed to pull repo (exit code #{exit_code})")
        {:error, :failed_to_pull}
    end
  end

  def ensure_checkout(repo_url, repo_path, git_ssh_command) do
    if !File.exists?(repo_path) do
      Logger.info("Setting up folder for config repo")
      {_, 0} = System.cmd("mkdir", ["-p", repo_path])
    end

    git_path = Path.join(repo_path, ".git")
    case File.exists?(git_path) do
      true ->
        {:ok, commit_hash(git_path)}
      false -> Logger.info("Cloning config repo from #{repo_url} into #{repo_path}")
        case System.cmd("git", ["clone", repo_url, repo_path], env: env(git_ssh_command)) do
        {_, 0} ->
            {:ok, commit_hash(repo_path)} 
        {_, exit_code} ->
            Logger.error("Failed to clone repo (exit code #{exit_code})")
            {:error, :failed_to_clone}
        end
    end
  end

  def checkout(commit_hash, repo_path, git_ssh_command) do
    {_, 0} = System.cmd("git", ["checkout", commit_hash], cd: repo_path, env: env(git_ssh_command), stderr_to_stdout: true)
    {:ok, commit_hash}
  end

  def default_branch(repo_path, git_ssh_command) do
    {reply, 0} = System.cmd("git", ["remote", "show", "origin"], cd: repo_path, env: env(git_ssh_command))
    [[[_, branch]]] = reply |> String.split("\n") |> Enum.map(&String.trim(&1)) |> Enum.map(&Regex.scan(~r/HEAD branch: (.*)/, &1)) |> Enum.filter(&(&1!=[]))
    branch
  end

  defp commit_hash(repo_path) do
    {commit_hash, 0} = System.cmd("git", ["log", "-1", "--format=%H"], cd: repo_path)
    commit_hash |> String.trim
  end

  defp env(nil), do: []
  defp env(command), do: [{"GIT_SSH_COMMAND", command}]
end
