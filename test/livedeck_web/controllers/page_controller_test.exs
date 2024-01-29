defmodule LivedeckWeb.PageControllerTest do
  use LivedeckWeb.ConnCase

  test "GET /hello/view", %{conn: conn} do
    conn = get(conn, ~p"/hello/view")
    assert html_response(conn, 200) =~ "Livedeck"
  end
end
