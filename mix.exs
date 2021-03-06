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
    [applications: [:logger, :ranch, :crypto, :cowlib, :cowboy, :plug],
     mod: {Numerino.Web, []}]
  end

  defp deps do
    [{:json, "~> 0.3.0"},
     {:cowboy, "1.0.0"},
     {:plug, "1.0.2"},
     {:uuid, "~> 1.1"},
     {:httpoison, "~> 0.8.0"},
     {:hackney, "~> 1.4"},
     {:heapq, "~> 0.0.1"}]
  end
end
