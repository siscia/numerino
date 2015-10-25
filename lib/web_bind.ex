defmodule Numerino.Web do
  @behaviour :application

  def start(_type, _args) do
    #{:ok, queue_counter} = Agent.start_link(fn -> HashDict.new end)
    {:ok, _} = Plug.Adapters.Cowboy.http Numerino.Plug, []
    Numerino.Supervisor.start_link []
    #{:ok, n} = Numerino.start_link [1, 2, 3, 4], fn p -> Numerino.QueueAddress.follow(p, "main") end
  end
end

#defmodule Numerino.QueueManager do
#
#  def start_link do
#    Agent.start_link fn -> HashDict.new end
#  end
#
#  def new_queue queue_manager, name, levels do
#    {:ok, n} = Numerino.start_link levels
#    ref = Process.monitor n
#    Agent.update(queue_manager, fn a -> (HashDict.put_new a, name, n)
#                                     |> (HashDict.put_new ref, name) end)
#  end
#
#end
#

defmodule Numerino.Plug do
  use Plug.Router
  use Plug.Debugger

  plug :put_resp_content_type, "application/json"
  plug :match
  plug :dispatch

  def init a do
    IO.inspect a
    a
  end

  get "/" do
    conn
    |> send_resp(201, "world")
  end

  post "/" do
    conn
  end

  post "/new" do
    conn
  end

  match _ do
    send_resp(conn, 404, "Not found.")
  end

end

defmodule Numerino.HTTPBench do

  def init(_type, req, n) do
    {:ok, req, n}
  end

  defp do_pop state, _request do
    {:ok, next} = Numerino.pop state
    JSON.encode!(next)
  end

  defp do_push(state, request) do
    {priority, element} = read_request(request)
    {:ok, object} = Numerino.push state, priority, element
    JSON.encode!({:ok, object})
  end

  defp read_request request do
    {:ok, body, _req} = :cowboy_req.body(request)
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

  def terminate _a, _b, _c do
    :ok
  end
end
