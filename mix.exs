defmodule ExGtin.Mixfile do
  @moduledoc """
  ExGtin `mix.exs`
  """
  use Mix.Project

  def project do
    [
      app: :ex_gtin,
      version: "1.0.1",
      elixir: "~> 1.4",
      description: description(),
      aliases: aliases(),
      package: package(),
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      coverallspreferred_cli_env: [
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      preferred_cli_env: [
        "pull_request_checkout.task": :test
      ],
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

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:credo, "~> 1.5.5", only: [:dev, :test]},
      {:ex_doc, "~> 0.23.0", only: :dev, runtime: false},
      {:excoveralls, "~> 0.14.0", only: :test}
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
    [c: "compile",
      "pull_request_checkout.task": [
        "test",
        "credo --strict",
        "coveralls"
      ],
    ]
  end

  defp description do
     """
       Elixir GTIN Validation Library for GS1, UPC-12, and GLN.
       Validates GTIN-8, GTIN-12 (UPC-12), GTIN-13 (GLN), GTIN-14 codes.
       Global Trade Item Number (GTIN)
       Universal Price Code (UPC)
     """
  end
end
