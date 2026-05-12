# ConfigServer

## Concept

Many applications need configuration that might change at runtime.
`ConfigServer` can deliver configuration which is stored in a git repository.

The repository is cloned into the local file system and pulled from the origin at regular intervals.

## Usage

```elixir
iex(1)> ConfigServer.start_link(%{repo_url: "https://ghp_XXX@github.com/odo/config_server", repo_path: "/tmp/config_server_checkout", pull_interval_ms: 1000})

17:54:56.756 [info] Setting up folder for config repo

17:54:56.764 [info] Cloning config repo
Cloning into '/tmp/config_server_checkout'...
                                             remote: Enumerating objects: 20, done.
remote: Counting objects: 100% (20/20), done.
remote: Compressing objects: 100% (14/14), done.
                                                remote: Total 20 (delta 0), reused 20 (delta 0), pack-reused 0 (from 0)
Unpacking objects: 100% (20/20), done.                                                                                 Unpacking objects:   5% (1/20)

{:ok, #PID<0.136.0>}

17:54:57.777 [info] Pulling config repo

17:54:58.778 [info] Pulling config repo

iex(2)> ConfigServer.config
%{
  "README.md" => "# ConfigServer\n\n**TODO: Add description**\n\n## Installation\n\nIf [available in Hex](https://hex.pm/docs/publish), the package can be installed\nby adding `config_server` to your list of dependencies in `mix.exs`:\n\n```elixir\ndef deps do\n  [\n    {:config_server, \"~> 0.1.0\"}\n  ]\nend\n```\n\nDocumentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)\nand published on [HexDocs](https://hexdocs.pm). Once published, the docs can\nbe found at <https://hexdocs.pm/config_server>.\n\n",
  "lib" => %{
[...]
```

## Parsing

The config repo is returned as one map with file names as keys and file content as values. Json files are parsed and the `.json` ending is filtered out.
