defmodule ShopifyAdminProxy.QueryHandler do
  @moduledoc false

  @spec fetch_normalized(String.t()) :: String.t() | {:error, any()}
  def fetch_normalized(body) do
    with {:ok, parsed} <- parse(body),
         {:ok, query} <- fetch_query(parsed) do
      normalize(query)
    end
  end

  @spec parse(String.t()) :: {:ok, term()} | {:error, Jason.DecodeError.t()}
  def parse(raw_http_body) when is_binary(raw_http_body), do: Jason.decode(raw_http_body)

  @spec fetch_query(map()) :: {:ok, String.t()} | :error
  def fetch_query(parsed_body), do: Map.fetch(parsed_body, "query")

  def query_files!,
    do: base_directory!() |> File.ls!() |> Enum.map(&Path.join([base_directory!(), &1]))

  def queries!, do: query_files!() |> Enum.map(&File.read!/1) |> Enum.map(&normalize/1)

  @doc """
  Normalizes a query body for matching and validation purposes.

  - Removes all whitespaces, " ", "\t", "\n"
  - Removes commas
  - Removes "__typename" as this is added by Apollo
  """
  @spec normalize(String.t()) :: String.t()
  def normalize(body),
    do: ~r/[\s+\n\,]/ |> Regex.replace(body, "") |> String.replace("__typename", "")

  def base_directory!,
    do: Application.get_env(:shopify_admin_proxy, :base_gpl_directory, "priv/proxy_queries")
end
