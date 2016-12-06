defmodule VideoProcessor.Mixfile do
  use Mix.Project

  def project do
    [app: :video_processor,
     version: "0.1.0",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [ mod: {VideoProcessor, []},
      applications: [:confex, :logger, :floki, :httpoison, :ex_aws, :hackney, :poison, :edeliver]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:confex, "~> 1.4.1"},
      {:httpoison, "~> 0.10.0"},
      {:poison, "~> 2.0"},
      {:floki, "~> 0.11.0"},
      {:ex_aws, "~> 1.0.0-rc.4"},
      {:hackney, "~> 1.6"},
      {:exjsx, "~> 3.2"},
      {:sweet_xml, "~> 0.5"},
      {:edeliver, "~> 1.4.0"},
      {:distillery, "~> 0.10"}
    ]
  end
end
