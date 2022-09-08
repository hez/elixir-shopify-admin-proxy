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

  def init(opts), do: ReverseProxyPlug.init(opts)

  def call(%{request_path: request_path} = conn, opts) do
    case Keyword.get(opts, :mount_path) == request_path do
      true -> conn |> AuthShopSessionToken.call([]) |> forward_conn(opts)
      false -> conn
    end
  end

  def forward_conn(%{halted: true} = conn, _opts), do: conn

  def forward_conn(%{assigns: %{shop: shop, auth_token: auth_token}} = conn, opts) do
    # cleanup the path info so ReverseProxyPlug doesn't try and use any of it
    conn = %{conn | path_info: []}

    opts =
      opts
      |> Keyword.put(:upstream, "https://#{shop.domain}")
      |> Keyword.put(:request_path, "/admin/api/#{configured_version()}/graphql.json")
      |> Keyword.put(:authority, shop.domain)
      |> Keyword.put(:host, shop.domain)
      |> Keyword.put(:port, 443)
      |> Keyword.put(:scheme, "https")

    body = ReverseProxyPlug.read_body(conn)

    case is_permitted_request?(body) do
      true ->
        Logger.debug("requesting shopify")

        conn
        |> assign(:raw_body, body)
        |> put_req_header("X-Shopify-Access-Token", auth_token.token)
        |> ReverseProxyPlug.call(opts)
        |> halt()

      _ ->
        Logger.warn("illegal request", myshopify_domain: shop.domain)

        conn
        |> resp(403, "Forbidden.")
        |> halt()
    end
  end

  def queries, do: @queries

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
