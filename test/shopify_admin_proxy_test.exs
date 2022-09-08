defmodule UpSell.Plug.ShopifyGraphQLProxyQueryHandlerTest do
  use ExUnit.Case
  alias ShopifyAdminProxy.QueryHandler

  @raw_http_body """
  {"operationName":"GetProducts","variables":{"first":25,"query":"","reverse":false,"sortKey":"TITLE"},"query":"query GetProducts($last: Int, $before: String, $first: Int, $after: String, $query: String, $sortKey: ProductSortKeys, $reverse: Boolean) {\\n  products(\\n    first: $first\\n    last: $last\\n    query: $query\\n    before: $before\\n    after: $after\\n    sortKey: $sortKey\\n    reverse: $reverse\\n  ) {\\n    edges {\\n      cursor\\n      node {\\n        id\\n        title\\n        handle\\n        status\\n        updatedAt\\n        featuredImage {\\n          id\\n          url(transform: {maxWidth: 88, maxHeight: 88, crop: CENTER})\\n          __typename\\n        }\\n        __typename\\n      }\\n      __typename\\n    }\\n    pageInfo {\\n      hasNextPage\\n      hasPreviousPage\\n      __typename\\n    }\\n    __typename\\n  }\\n}"}
  """

  @query_body """
  query GetProducts($last: Int, $before: String, $first: Int, $after: String, $query: String, $sortKey: ProductSortKeys, $reverse: Boolean) {\n  products(\n    first: $first\n    last: $last\n    query: $query\n    before: $before\n    after: $after\n    sortKey: $sortKey\n    reverse: $reverse\n  ) {\n    edges {\n      cursor\n      node {\n        id\n        title\n        handle\n        status\n        updatedAt\n        featuredImage {\n          id\n          url(transform: {maxWidth: 88, maxHeight: 88, crop: CENTER})\n          __typename\n        }\n        __typename\n      }\n      __typename\n    }\n    pageInfo {\n      hasNextPage\n      hasPreviousPage\n      __typename\n    }\n    __typename\n  }\n}
  """

  @expected "queryGetProducts($last:Int$before:String$first:Int$after:String$query:String$sortKey:ProductSortKeys$reverse:Boolean){products(first:$firstlast:$lastquery:$querybefore:$beforeafter:$aftersortKey:$sortKeyreverse:$reverse){edges{cursornode{idtitlehandlestatusupdatedAtfeaturedImage{idurl(transform:{maxWidth:88maxHeight:88crop:CENTER})}}}pageInfo{hasNextPagehasPreviousPage}}}"

  test "normalize/1" do
    assert QueryHandler.normalize(@query_body) == @expected
  end

  test "fetch_normalized/1" do
    assert QueryHandler.fetch_normalized(@raw_http_body) == @expected
  end
end
