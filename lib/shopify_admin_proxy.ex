defmodule ShopifyAdminProxy do
  @moduledoc """
  ShopifyAdminProxy proxys the Admin UI graphql request through to Shopify.
  It is limited to what queries can be performed and the shop has to have the App
  install to use it. The module uses AuthShopSessionToken plug from ShopifyAPI to
  authenticate the shop's JWT and uses the ReverseProxyPlug module to do the actual
  HTTP calls back to Shopify.

  The proxy is mounted at the :mount_path option
  """
  import Plug.Conn, only: [assign: 3, halt: 1, resp: 3]
  require Logger

  alias ShopifyAPI.Plugs.AuthShopSessionToken
  alias ShopifyAdminProxy.QueryHandler

  defdelegate configured_version(), to: ShopifyAPI.GraphQL

  @use_cached_queries Application.compile_env(:shopify_admin_proxy, :use_cached_queries, true)
  @use_online_tokens Application.compile_env(:shopify_admin_proxy, :use_online_tokens, false)

  if @use_cached_queries do
    @queries QueryHandler.queries!()
    def queries, do: @queries
  else
    def queries, do: QueryHandler.queries!()
  end

  def init(opts), do: ReverseProxyPlug.init(opts)

  def call(%{request_path: request_path} = conn, opts) do
    case Keyword.get(opts, :mount_path) == request_path do
      true ->
        conn
        |> AuthShopSessionToken.call(use_online_tokens: @use_online_tokens)
        |> forward_conn(opts)

      false ->
        conn
    end
  end

  def forward_conn(%{halted: true} = conn, _opts), do: conn

  def forward_conn(%{assigns: %{shop: shop}} = conn, opts) do
    body = ReverseProxyPlug.read_body(conn)

    with {:ok, auth_token} <- token_from_conn(conn),
         true <- permitted_request?(body) do
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
    else
      {:error, :no_token_found} ->
        Logger.warning("No auth token found.")
        conn |> resp(403, "Forbidden.") |> halt()

      false ->
        Logger.warning("illegal request", myshopify_domain: shop.domain)
        conn |> resp(403, "Forbidden.") |> halt()
    end
  end

  def req_headers(auth_token) when is_binary(auth_token) do
    [
      {"Content-Type", "application/json"},
      {"X-Shopify-Access-Token", auth_token}
    ]
  end

  # Use the user token if it is present
  defp token_from_conn(%{assigns: %{user_token: %{token: token}}}), do: {:ok, token}
  defp token_from_conn(%{assigns: %{auth_token: %{token: token}}}), do: {:ok, token}
  defp token_from_conn(_), do: {:error, :no_token_found}

  defp permitted_request?(body) do
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
