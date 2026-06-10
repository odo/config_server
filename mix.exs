defmodule ConfigServer.MixProject do
  use Mix.Project

  def project do
    [
      app: :config_server,
      version: "0.3.3",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      package: package(),
      deps: deps()
    ]
  end

  def application do
    case Mix.env do
      :test ->
        []
      _ ->
        [
          mod: {ConfigServer.Application, []},
          extra_applications: [:logger]
        ]
    end
  end

  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp package() do
    [
     name: "config_server",
     description: "Load configs from a git repo that is kept up to date",
     links: %{"GitHub" => "https://github.com/odo/config_server"},
     licenses: ["MIT"],
    ]
  end
end
