defmodule ImageFinder.Mixfile do
  use Mix.Project

  def project do
    [app: :image_finder,
     version: "0.0.2",
     elixir: "~> 1.20",
     build_embedded: Mix.env() == :prod,
     start_permanent: Mix.env() == :prod,
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :tesla, :wx, :observer, :runtime_tools],
     mod: {ImageFinder, []}]
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
  defp deps() do
    [
      {:tesla, "~> 1.21"},

      # optional, but recommended adapter
      {:hackney, "~> 1.25"},

      # optional, required by JSON middleware
      {:jason, ">= 1.4.5"}
    ]
  end
end
