defmodule ShopifyAdminProxy.MixProject do
  use Mix.Project

  @version "0.3.3"

  def project do
    [
      app: :shopify_admin_proxy,
      version: @version,
      elixir: "~> 1.15",
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
      {:credo, "~> 1.7.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4.1", only: [:dev, :test], runtime: false},
      # Prod
      {:jason, "~> 1.4"},
      {:shopify_api, github: "orbit-apps/elixir-shopifyapi", tag: "v0.15.5"},
      {:reverse_proxy_plug, "~> 2.2"}
    ]
  end
end
