# ShopifyAdminProxy

A simple proxy for forwarding requests to the Shopify Admin API.

The proxy uses the [ShopifyAPI authentication plug](https://github.com/orbit-apps/elixir-shopifyapi/blob/main/lib/shopify_api/plugs/auth_shop_session_token.ex) to validate the Shop's JWT, it then uses the Admin API token for the Shopify App to query the Shopify GraphQL Admin API. This is useful if you are building out your Admin React app and want to query for things held in Shopify but don't want to have to create an entire translation layer/API.

## Installation

```elixir
def deps do
  [
    {:shopify_admin_proxy, github: "hez/elixir-shopify-admin-proxy", branch: "v0.1.5"}
  ]
end
```

The proxy requires all your GraphQL queries are stored in their own directory, this is then used to allow only requests you have explicitly added to the app. This is done by setting the config for `:shopify_admin_proxy`.

Add the following to your `config/config.exs` substituting in your own directory.

```elixir
# Allowed queries for shopify admin proxy
config :shopify_admin_proxy,
  base_gpl_directory: Path.expand("../admin_ui/src/graphql/shopify", __DIR__)
```

The proxy defaults to caching all graphql query files in the module, to disable this for development add the following to `config/dev.exs`

```elixir
# Disable query compile time caching for dev
config :shopify_admin_proxy, use_cached_queries: false
```

Since the proxy forwards the entire body of the request you will have to mount the proxy in your endpoint before the `Plug.Parsers` gets called. You can ignore `upstream: ...` here, it is required by the proxy library used but gets replaced at time of calling.

Example:

```elixir
  plug ShopifyAdminProxy,
    upstream: "https://example.myshopify.com/admin/api/2022-04/graphql.json",
    mount_path: "/api/admin/shopify_graphql_proxy"

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    ....
```
