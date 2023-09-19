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

  @use_cached_queries Application.compile_env(:shopify_admin_proxy, :use_cached_queries, true)

  if @use_cached_queries do
    @queries QueryHandler.queries!()
    def queries, do: @queries
  else
    def queries, do: QueryHandler.queries!()
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
        Logger.warning("illegal request", myshopify_domain: shop.domain)

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

  defp is_permitted_request?(body) do
    normalized = QueryHandler.fetch_normalized(body)

    case Enum.any?(queries(), &(&1 == normalized)) do
      true ->
        true

      false ->
        Logger.warning("Failed to proxy query, not found in existing allowed list")
        Logger.debug("Query attempted, #{inspect(normalized)}")
        false
    end
  end
end
