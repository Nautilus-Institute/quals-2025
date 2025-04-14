defmodule SevenElBeeWeb.PageController do
  use SevenElBeeWeb, :controller

  def health(conn, _params) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, ~s(ok))
  end
end
