defmodule ConfigServer.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [ConfigServer]

    opts = [strategy: :one_for_one, name: ConfigServer.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
