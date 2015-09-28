defmodule Numerino.Web do
  @behaviour :application

  def start(_type, _args) do
    {:ok, n} = Numerino.start_link ["critical", "high", "medium", "low"]
    dispatch = :cowboy_router.compile([
      {:_, [{"/", Numerino.HTTPBench, n}]}
    ])
    {:ok, _} = :cowboy.start_http(:http, 100, [{:port, 8080}], [{:env, [{:dispatch, dispatch}]}])
    IO.inspect "Server is running on 8080..."
    Numerino.Supervisor.start_link []
  end  

end

defmodule Numerino.HTTPBench do

  def init(_type, req, n) do
    {:ok, req, n}
  end

  defp do_pop state, request do
    {:ok, next} = Numerino.pop state
    JSON.encode!(next)
  end

  defp do_push(state, request) do
    {priority, element} = read_request(request)
    {:ok, object} = Numerino.push state, priority, element
    JSON.encode!({:ok, object})
  end

  defp read_request request do
    {:ok, body, req} = :cowboy_req.body(request)
    {:ok, %{"priority" => p, "element" => e}} = JSON.decode(body)
    {p, e} 
  end

  def handle(request, state) do
    case :cowboy_req.method(request) do
      {"GET", req} ->  {:ok, rep} = :cowboy_req.reply(
          200,
          [],
          do_pop(state, request),
          req
      ) 
      {"POST", req} -> {:ok, rep} = :cowboy_req.reply(
          200,
          [],
          do_push(state, request),
          req
      )
    end
    {:ok, rep, state}
  end

  def terminate a, b, c do
    :ok
  end

end
