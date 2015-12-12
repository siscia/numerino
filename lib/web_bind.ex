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
  use Plug.Debugger
  use Plug.ErrorHandler 
  
  plug Plug.Parsers, parsers: [:json],
                     json_decoder: JSON
  plug :put_resp_content_type, "application/json"
  plug :match
  plug :dispatch

  post "/transient" do
    case create_queue(conn.params) do
      {:ok, name, "transient", p} -> send_resp(conn, 201, 
                        JSON.encode!(%{result: :ok, 
                                       message: "New transient queue created", 
                                       queue: %{
                                                 name: name,
                                                 type: "transient",
                                                 priorities: p}}))
      {:error, message} -> send_resp(conn, 400, message)
    end
  end

  get "/transient/:name" do
    case :ets.lookup Numerino.QueueAddress, name do
      [{^name, pid, _priorities}] -> pop_from_transit_queue conn, pid
      [] -> send_resp(conn, 400, 
            JSON.encode!(%{status: :error, 
                           message: "The transit queue #{name} does not exist."}))
    end
  end

  def pop_from_transit_queue conn, pid do
    case Numerino.pop(pid) do
      {:ok, :EOF} -> send_resp(conn, 404, JSON.encode!(%{status: :end_of_queue, message: "Not element in the queue"}))
      {:ok, {priority, message}} -> send_resp(conn, 200, JSON.encode!(%{status: :ok, message: message, priority: priority}))
    end
  end

  post "/transient/:name" do
    case :ets.lookup Numerino.QueueAddress, name do
      [{^name, pid, _priorities}] -> push_to_transient_queue conn, pid
      [] -> send_resp(conn, 400, 
              JSON.encode!(%{status: :error,
                             message: "The transit queue #{name} does not exist."}))
    end
  end

  def push_to_transient_queue conn, pid do
    %{"priority" => priority, "message" => message} = conn.params
    case Numerino.push pid, priority, message do
      {:error, :not_found_priority} -> send_resp(conn, 400, error_push(priority, message))
      {:ok, {priority, message}} -> send_resp(conn, 200, success_message(priority, message)) 
    end
  end

  post "/persistent" do
    case create_queue(conn.params) do
      {:ok, id, "persistent", p} -> send_resp(conn, 201,
                    JSON.encode!(%{result: :ok,
                                   message: "New persistent queue created",
                                   queue: %{name: id,
                                            type: "persistent",
                                            priorities: p
                                   }}))
      {:error, message} -> send_resp(conn, 400, message)
    end
  end

  get "/persistent/:id" do
    id = String.to_integer(id)
    case :ets.lookup(Numerino.QueueAddress, id) do
      [{id, pid, :persistent}] -> pop_from_persistent_activated_queue(conn, pid)
      [] -> case activate_queue(id) do
              {:ok, pid} -> pop_from_persistent_activated_queue(conn, pid)
              {:error, _} -> send_resp conn, 400, JSON.encode!(%{status: :error, message: "The queue #{id} does not exist yet."})
            end
    end
  end

  defp pop_from_persistent_activated_queue(conn, pid) do
    case NumerinoPersistent.pop pid do
      {:ok, :EOF} -> send_resp(conn, 404, JSON.encode!(%{status: :end_of_queue, message: "Not element in the queue"}))
      {:ok, {_id, message}} -> send_resp(conn, 200, JSON.encode!(%{status: :ok, message: message}))
    end
  end

  post "/persistent/:id" do
    id = String.to_integer(id)
    case :ets.lookup(Numerino.QueueAddress, id) do
      [{id, pid, :persistent}] -> push_to_persistent_activated_queue(conn, pid)
      [] -> case activate_queue id do
              {:ok, pid} -> push_to_persistent_activated_queue(conn, pid)
              {:error, _} -> send_resp(conn, 400, 
                                        JSON.encode!(%{status: :error, 
                                                       message: "The queue #{id} does not exist yet."}))
            end
    end
  end

  defp push_to_persistent_activated_queue(conn, pid) do
    %{"priority" => priority, "message" => message} = conn.params
    priority = to_string(priority)
    case NumerinoPersistent.push pid, priority, message do
      {:ok, _} -> send_resp(conn, 200, success_message(priority, message))
      {:error, :not_found_priority} -> send_resp(conn, 400, error_push(priority, message))
    end
  end

  defp activate_queue queue_id do
    Numerino.QueueManager.Persistent.new_queue(:existing, queue_id)
  end

  match _ do
    send_resp(conn, 400, "Not found.")
  end

  defp create_queue %{"type" => "transient", "priorities" => p} do
    name = UUID.uuid4(:hex)
    {:ok, _pid} = Numerino.QueueManager.Transient.new_queue(name, p)
    {:ok, name, "transient", p}
  end

  defp create_queue %{"type" => "persistent", "priorities" => p} do
    {:ok, pid} = Numerino.QueueManager.Persistent.new_queue(:new, 1, p)
    id = NumerinoPersistent.get_queue_id pid
    {:ok, id, "persistent", p}
  end

  defp load_persistent_queue id do
    {:ok, p} = Numerino.QueueManager.Persistent.new_queue(:existing, 1, id)
    {:ok, id}
  end

  defp create_queue _ do
    {:error, "Unable to understad your command."}
  end

  defp handle_errors conn, %{kind: :error, reason: %Plug.Parsers.ParseError{}, stack: _stack} do
    send_resp(conn, 400, "Your JSON wasn't valid")
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

