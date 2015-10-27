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

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [:logger, :ranch, :crypto, :cowlib, :cowboy, :plug, :sqlite_ecto, :ecto],
     mod: {Numerino.Web, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    [{:json, "~> 0.3.0"},
     {:cowboy, "1.0.0"},
     {:plug, "1.0.2"},
     {:ecto, "1.0.6"},
     {:sqlite_ecto, "~> 1.0.0"},
     {:uuid, "~> 1.1"}, ]
  end
end
