defmodule ShopifyAdminProxy.MixProject do
  use Mix.Project

  @version "0.1.4"

  def project do
    [
      app: :shopify_admin_proxy,
      version: @version,
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [
        plt_add_apps: [:mix, :ex_unit],
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # dev and test
      {:credo, "~> 1.6.4", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.2.0", only: [:dev, :test], runtime: false},
      # Prod
      {:jason, "~> 1.4"},
      {:shopify_api, github: "orbit-apps/elixir-shopifyapi", tag: "v0.13.7"},
      {:reverse_proxy_plug, "~> 2.1"}
    ]
  end
end
