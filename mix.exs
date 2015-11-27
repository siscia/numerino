defmodule Numerino.Mixfile do
  use Mix.Project

  def project do
    [app: :numerino,
     version: "0.0.1",
     elixir: "~> 1.0",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  def application do
    [applications: [:logger, :ranch, :crypto, :cowlib, :cowboy, :plug, :sqlite_ecto, :ecto],
     mod: {Numerino.Web, []}]
  end

  defp deps do
    [{:json, "~> 0.3.0"},
     {:cowboy, "1.0.0"},
     {:plug, "1.0.2"},
     {:esqlite, "0.2.1"},
     {:sqlite_ecto, "~> 1.0.0"},
     {:comeonin, "~> 1.3.0"},
     {:uuid, "~> 1.1"}]
  end
end
