defmodule ShopifyAdminProxy do
  @moduledoc """
  ShopifyAdminProxy proxys the Admin UI graphql request through to Shopify.
  It is limited to what queries can be performed and the shop has to have the App
  install to use it. The module uses AuthShopSessionToken plug from ShopifyAPI to
  authenticate the shop's JWT and uses the ReverseProxyPlug module to do the actual
  HTTP calls back to Shopify.

  The proxy is mounted at the :mount_path option
  """
  import Plug.Conn
  require Logger
  alias ShopifyAPI.Plugs.AuthShopSessionToken
  alias ShopifyAdminProxy.QueryHandler

  defdelegate configured_version(), to: ShopifyAPI.GraphQL

  @queries QueryHandler.queries!()

  # Add external link to all the query files, telling mix to recompile if they change
  for query_file <- QueryHandler.query_files!() do
    @external_resource query_file
  end

  def init(opts), do: ReverseProxyPlug.init(opts)

  def call(%{request_path: request_path} = conn, opts) do
    case Keyword.get(opts, :mount_path) == request_path do
      true -> conn |> AuthShopSessionToken.call([]) |> forward_conn(opts)
      false -> conn
    end
  end

  def forward_conn(%{halted: true} = conn, _opts), do: conn

  def forward_conn(%{assigns: %{shop: shop, auth_token: auth_token}} = conn, opts) do
    body = ReverseProxyPlug.read_body(conn)

    case is_permitted_request?(body) do
      true ->
        Logger.debug("requesting shopify")

        opts =
          opts
          |> Keyword.put(:upstream, "https://#{shop.domain}")
          |> Keyword.put(:request_path, "/admin/api/#{configured_version()}/graphql.json")
          |> Keyword.put(:authority, shop.domain)
          |> Keyword.put(:host, shop.domain)
          |> Keyword.put(:port, 443)
          |> Keyword.put(:scheme, "https")

        # Cleanup the path info so ReverseProxyPlug doesn't try and use any of it and
        # set our request headers, Shopify can redirect to shop.myshopify.com/admin/login
        # if specific headers are passed through.
        %{conn | path_info: [], req_headers: req_headers(auth_token)}
        |> assign(:raw_body, body)
        |> ReverseProxyPlug.call(opts)
        |> halt()

      _ ->
        Logger.warn("illegal request", myshopify_domain: shop.domain)

        conn
        |> resp(403, "Forbidden.")
        |> halt()
    end
  end

  def req_headers(auth_token) do
    [
      {"Content-Type", "application/json"},
      {"X-Shopify-Access-Token", auth_token.token}
    ]
  end

  def queries, do: @queries

  # Check MD5 of queries vs cached to tell mix whether we should recompile this module
  def __mix_recompile__?, do: :erlang.md5(QueryHandler.queries!()) != :erlang.md5(@queries)

  defp is_permitted_request?(body) do
    normalized = QueryHandler.fetch_normalized(body)

    case Enum.any?(queries(), &(&1 == normalized)) do
      true ->
        true

      false ->
        Logger.warn("Failed to proxy query, not found in existing allowed list")
        Logger.debug("Query attempted, #{inspect(normalized)}")
        false
    end
  end
end
