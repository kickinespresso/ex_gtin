defmodule ExGtin.Mixfile do
  @moduledoc """
  ExGtin `mix.exs`
  """
  use Mix.Project

  def project do
    [
      app: :ex_gtin,
      version: "1.4.0",
      elixir: "~> 1.15",
      description: description(),
      aliases: aliases(),
      package: package(),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      # Docs
      name: "ExGtin",
      source_url: "https://github.com/kickinespresso/ex_gtin",
      homepage_url: "https://github.com/kickinespresso/ex_gtin",
      docs: [
        main: "ExGtin",
        extras: ["README.md"]
      ]
    ]
  end

  # CLI configuration (preferred environments per task)
  #
  # Type "mix help cli" for more information
  def cli do
    [
      preferred_envs: [
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "pull_request_checkout.task": :test
      ]
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:credo, "~> 1.7.19", only: [:dev, :test]},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      {:excoveralls, "~> 0.18.5", only: :test},
      {:stream_data, "~> 1.1", only: [:dev, :test]}
    ]
  end

  defp package do
    [
      name: "ex_gtin",
      maintainers: ["KickinEspresso"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/kickinespresso/ex_gtin"}
    ]
  end

  defp aliases do
    [
      c: "compile",
      "pull_request_checkout.task": [
        "test",
        "credo --strict",
        "coveralls",
        "format --check-formatted"
      ]
    ]
  end

  defp description do
    """
      Elixir Global Trade Item Number (GTIN) Validation Library for GS1, UPC-12, and GLN.
      Validates GTIN-8, GTIN-12 (UPC-12), GTIN-13 (GLN), GTIN-14 codes.
      Universal Price Code (UPC)
    """
  end
end
