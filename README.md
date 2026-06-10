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

If you are using `ssh`:

```
config :config_server,
  repo_url: "git@github.com:odo/config_server",
  git_ssh_command: "ssh -i ~/.ssh/my_private_key", 
  repo_path: "/tmp/config_server_checkout",
  pull_interval_ms: 1000,
  state_change_fun: fn(old_config, new_config) -> IO.inspect({old_config, new_config}) end
```


`state_change_fun` can be skipped or can be defined as `{module, function}`.

## Usage

To retrieve the current config, call `ConfigServer.config()`.

Whenever a new version of the config is pulled, `state_change_fun` will be called with the old config and  the new config as arguments.
At application start it will be called once with `nil` and the current config.


## Format

The config repo is returned as a map with file names as keys and file content as values. Json files are parsed and the `.json` ending is filtered out. Files and directories starting with dots are ignored.
