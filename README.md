# ConfigServer

## Concept

Many applications need configuration that might change at runtime.
`ConfigServer` can deliver configuration which is stored in a git repository.

The repository is cloned into the local file system and pulled from the origin at regular intervals.

## Installation

The package can be installed by adding `config_server` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:config_server, "~> 0.3.3"}
  ]
end
```

## Configuration

If you are using `http`:

```
config :config_server,
  repo_url: "https://ghp_XXX@github.com/odo/config_server",
  repo_path: "/tmp/config_server_checkout",
  pull_interval_ms: 1000,
  state_change_fun: fn(old_config, new_config) -> IO.inspect({old_config, new_config}) end
```

If you are using `ssh` and want a specific branch to be used:

```
config :config_server,
  repo_url: "git@github.com:odo/config_server",
  git_ssh_command: "ssh -i ~/.ssh/my_private_key", 
  repo_path: "/tmp/config_server_checkout",
  branch: "staging",
  pull_interval_ms: 1000,
  state_change_fun: fn(old_config, new_config) -> IO.inspect({old_config, new_config}) end
```

### repo_url
This can be
* A directory `file://path/to/repo/directory`
* A HTTP URL like `https://token@github.com/foo/bar`
* SSH path like `git@github.com:odo/config_server` together with `git_ssh_command` (see above) 

### repo_path
A path where the checkout of your configuration repository lives.

### state_change_fun as (any(), any()) -> :ok | :error | {:error, any()}
This can be skipped or can be defined as `{module, function}`.
`ConfigServert` will pass in the old and new configuration as arguments. Intially, the old config will be `nil`. 
If `state_change_fun` returns `:error` or `{:error, something}` then that means that the configuration is faulty and `ConfigServer` rolls back to the previous configuration.

## Usage

To retrieve the current configuration, call `ConfigServer.config()`.

## Format

The config repo is returned as a map with file names as keys and file content as values. Json files are parsed and the `.json` ending is filtered out. Files and directories starting with dots are ignored.
