defmodule Matsou.Mixfile do
  use Mix.Project

  def project do
    [app: :matsou,
     version: "0.0.1",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :riak]]
  end

  defp deps do
    [{:riak, "~> 1.1.0", only: [:dev, :test]},
     {:uuid, "~> 1.1.4"}]
  end
end
