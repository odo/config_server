defmodule ConfigServerTest do
  use ExUnit.Case, async: false
  doctest ConfigServer

  setup() do
    :ets.delete(ConfigServer)
    :ok
  rescue
    _ -> :ok
  end

  test "init and load good config" do
    {origin_dir, checkout_dir, _commit_hash} = init()
    state = init_state(origin_dir, checkout_dir, state_change_fun(:ok))

    ConfigServer.handle_cast(:initial_load, state)
    assert_receive({:config_change, {nil, %{"test" => %{}}}}, 1)

    assert %{"test" => %{}} == ConfigServer.config()
  end
  
  test "init and load broken config" do
    {origin_dir, checkout_dir, _commit_hash} = init()

    state = init_state(origin_dir, checkout_dir, state_change_fun({:error, :bad_config}))
    assert {:error, :no_known_good_state} == catch_throw(ConfigServer.handle_cast(:initial_load, state))
  end

  test "init and load good config, then update" do
    {origin_dir, checkout_dir, init_commit_hash} = init()
    state = init_state(origin_dir, checkout_dir, state_change_fun(:ok))

    {:noreply, state} = ConfigServer.handle_cast(:initial_load, state)
    assert_receive({:config_change, {nil, %{"test" => %{}}}}, 1)
    assert %{"test" => %{}} == ConfigServer.config()


    assert init_commit_hash == commit_hash(origin_dir)
    commit_hash = add_file_and_commit("test2.json", origin_dir)
    ConfigServer.handle_info(:pull_configs, state)
    assert_receive({:config_change, {%{"test" => %{}}, %{"test" => %{}, "test2" => %{}}}}, 1)
    assert commit_hash == commit_hash(origin_dir)
    assert %{"test" => %{}, "test2" => %{}} == ConfigServer.config()
  end

  test "init and load good config, then bad, then roll back" do
    {origin_dir, checkout_dir, init_commit_hash} = init()
    state = init_state(origin_dir, checkout_dir, state_change_fun(:ok))

    {:noreply, state} = ConfigServer.handle_cast(:initial_load, state)
    assert_receive({:config_change, {nil, %{"test" => %{}}}}, 1)
    assert %{"test" => %{}} == ConfigServer.config()

    _bad_commit_hash = add_file_and_commit("test2.json", origin_dir)
    state = %ConfigServer{state | state_change_fun: state_change_fun({:error, :bad_config})}
    {:noreply, _state} = ConfigServer.handle_info(:pull_configs, state)
    assert_receive({:config_change, {%{"test" => %{}}, %{"test" => %{}, "test2" => %{}}}}, 1)
    assert init_commit_hash == commit_hash(checkout_dir)
    assert %{"test" => %{}} == ConfigServer.config()
  end

  test "init and load good config, then bad, then roll back, then load next good one" do
    {origin_dir, checkout_dir, init_commit_hash} = init()
    state = init_state(origin_dir, checkout_dir, state_change_fun(:ok))

    {:noreply, state} = ConfigServer.handle_cast(:initial_load, state)
    assert_receive({:config_change, {nil, %{"test" => %{}}}}, 1)
    assert %{"test" => %{}} == ConfigServer.config()
    
    _bad_commit_hash = add_file_and_commit("test2.json", origin_dir)
    state = %ConfigServer{state | state_change_fun: state_change_fun({:error, :bad_config})}
    {:noreply, state} = ConfigServer.handle_info(:pull_configs, state)
    assert_receive({:config_change, {%{"test" => %{}}, %{"test" => %{}, "test2" => %{}}}}, 1)
    assert init_commit_hash == commit_hash(checkout_dir)
    assert %{"test" => %{}} == ConfigServer.config()

    good_commit_hash = add_file_and_commit("test3.json", origin_dir)
    state = %ConfigServer{state | state_change_fun: state_change_fun(:ok)}
    {:noreply, _state} = ConfigServer.handle_info(:pull_configs, state)
    assert_receive({:config_change, {%{"test" => %{}}, %{"test" => %{}, "test2" => %{}, "test3" => %{}}}}, 1)
    assert good_commit_hash == commit_hash(checkout_dir)
    assert %{"test" => %{}, "test2" => %{}, "test3" => %{}} == ConfigServer.config()

  end

  def state_change_fun(return_value) do
    me = self()
    fn(old_config, new_config) ->
      IO.inspect({old_config, new_config}, label: :callback)
      Process.send(me, {:config_change, {old_config, new_config}}, [])
      return_value
    end
  end

  defp init() do
    test_dir = System.tmp_dir!()
    origin_dir = Path.join(test_dir, "origin")
    checkout_dir = Path.join(test_dir, "checkout")
    [origin_dir, checkout_dir]
      |> Enum.each(fn(dir) -> File.rm_rf!(dir); File.mkdir(dir) end)
    File.mkdir(origin_dir) 
    File.mkdir(checkout_dir) 
    System.cmd("git", ["init"], cd: origin_dir)
    commit_hash = add_file_and_commit("test.json", origin_dir)
    {origin_dir, checkout_dir, commit_hash}
  end

  defp add_file_and_commit(filname, origin_dir) do
    System.cmd("git", ["init"], cd: origin_dir)
    File.write!(Path.join(origin_dir, filname), "{}")
    System.cmd("git", ["add", filname], cd: origin_dir)
    System.cmd("git", ["commit", "-m", "adding " <> filname], cd: origin_dir)
    commit_hash(origin_dir)
  end

  defp init_state(origin_dir, checkout_dir, state_change_fun) do
    {:ok, state} =
    ConfigServer.init(%{
        repo_url: "file://" <> origin_dir,
        repo_path: checkout_dir,
        branch: nil,
        git_ssh_command: nil,
        pull_interval_ms: 1_000_000,
        state_change_fun: state_change_fun
      }
    )
    state
  end
  
  defp commit_hash(repo_path) do
    {commit_hash, 0} = System.cmd("git", ["log", "-1", "--format=%H"], cd: repo_path)
    commit_hash |> String.trim
  end

end
