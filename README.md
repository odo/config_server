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
    {:config_server, "~> 0.1.0"}
  ]
end
```

## Configuration

```
config :config_server,
  repo_url: "https://ghp_XXX@github.com/odo/config_server",
  repo_path: "/tmp/config_server_checkout",
  pull_interval_ms: 1000,
  state_change_fun: fn(old_config, new_config) -> IO.inspect({old_config, new_config}) end
```

`state_change_fun` can be skipped.

## Usage

Whenever a new version of the config is pulled, `state_change_fun` will be called with the old config and  the new config as arguments.
At application start it will be called once with `nil` and the current config.

To retrieve the current config, call `ConfigServer.config()`.

## Format

The config repo is returned as a map with file names as keys and file content as values. Json files are parsed and the `.json` ending is filtered out. Files and directories starting with dots are ignored.
