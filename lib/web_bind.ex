defmodule Numerino.Web do
  @behaviour :application

  def start(_type, _args) do
    {:ok, _} = Plug.Adapters.Cowboy.http Numerino.Plug, []
    :observer.start()
    Numerino.Supervisor.start_link []
  end  
end

defmodule Numerino.Plug do
  use Plug.Router
  use Plug.ErrorHandler 
  
  plug Plug.Parsers, parsers: [:json],
                     json_decoder: JSON
  plug :put_resp_content_type, "application/json"
  plug :match
  plug :dispatch

  post "/new" do
    case create_queue conn.params do
      {:ok, name} -> send_resp(conn, 200, 
                        JSON.encode!(%{result: :ok, 
                                       message: "New queue created", 
                                       name: name}))
      {:error, message} -> send_resp(conn, 400, message)
    end
  end

  get "/:name" do  ## pop
    [{name, pid, _priorities}] = :ets.lookup Numerino.QueueAddress, name
    a = Numerino.pop pid
    IO.inspect a
    case a do
      {:ok, :EOF} -> send_resp(conn, 402, JSON.encode!(%{status: :end_of_queue, message: "Not element in the queue"}))
      {:ok, {priority, message}} -> send_resp(conn, 200, JSON.encode!(%{status: :ok, message: message, priority: priority}))
    end
  end

  post "/:name" do
    [{name, pid, _priorities}] = :ets.lookup Numerino.QueueAddress, name
    %{"priority" => priority, "message" => message} = conn.params
    case Numerino.push pid, priority, message do
      {:error, :not_found_priority} -> send_resp(conn, 402, error_push(priority, message))
      {:ok, {priority, message}} -> send_resp(conn, 201, success_message(priority, message)) 
    end
  end

  match _ do
    send_resp(conn, 404, "Not found.")
  end

  defp create_queue %{"type" => "transient", "priorities" => p} do
    name = UUID.uuid4(:hex)
    {:ok, _p} = Numerino.QueueManager.new_queue(name, p)
    {:ok, name}
  end

  defp create_queue wrong do
    {:error, "Wrong map"}
  end

  defp handle_errors conn, %{kind: _kind, reason: _reason, stack: _stack} do
    IO.inspect conn
    send_resp(conn, 400, "Something went wrong!")
  end

  defp error_push priority, message do
    JSON.encode!( %{result: :error, 
                    message: "Not found priority #{priority}", 
                    priority: priority, message: message})
  end

  defp success_message priority, object do
    JSON.encode!( %{result: :success, 
                    message: "Insert new object with the message: #{object} under the priority #{priority}", 
                    priority: priority, message: object})
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
