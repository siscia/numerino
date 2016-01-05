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

  post "/" do
    case create_queue(conn.params) do
      {:ok, name, "transient", p} -> send_resp(conn, 201, 
                        JSON.encode!(%{status: :ok, 
                                       message: "New transient queue created", 
                                       queue: %{name: name,
                                                type: "transient",
                                                priorities: p}}))
      {:error, message} -> send_resp(conn, 400, message)
    end
  end

  get "/:name" do
    case :ets.lookup Numerino.QueueAddress, name do
      [{^name, pid, _priorities}] -> pop_from_transit_queue conn, pid
      [] -> send_resp(conn, 400, 
            JSON.encode!(%{status: :error, 
                           message: "The transit queue #{name} does not exist."}))
    end
  end

  defp pop_from_transit_queue conn, pid do
    case Numerino.Transient.pop(pid) do
      {:ok, :EOF} -> send_resp(conn, 404, JSON.encode!(%{status: :end_of_queue, message: "Not element in the queue"}))
      {:ok, {priority, message}} -> send_resp(conn, 200, JSON.encode!(%{status: :ok, message: message, priority: priority}))
    end
  end

  post "/:name" do
    case :ets.lookup Numerino.QueueAddress, name do
      [{^name, pid, _priorities}] -> push_to_transient_queue conn, pid
      [] -> send_resp(conn, 400, 
              JSON.encode!(%{status: :error,
                             message: "The transit queue #{name} does not exist."}))
    end
  end

  delete "/:name" do
    case :ets.lookup(Numerino.QueueAddress, name) do
      [{^name, pid, _priorities}] -> delete_transient_queue(conn, pid, name)
      [] -> send_resp(conn, 400, 
              JSON.encode!(%{status: :error,
                             message: "The transit queue #{name} does not exist."}))
 
    end
  end

  defp push_to_transient_queue conn, pid do
    %{"priority" => priority, "message" => message} = conn.params
    case Numerino.Transient.push pid, priority, message do
      {:error, :not_found_priority} -> send_resp(conn, 400, error_push(priority, message))
      {:ok, {priority, message}} -> send_resp(conn, 200, success_message(priority, message)) 
    end
  end

  defp delete_transient_queue(conn, pid, name) do
    case Numerino.QueueManager.Transient.terminate_child(pid, name) do
      :ok -> send_resp(conn, 200, JSON.encode!(%{status: :ok, message: "Successfully deleted queue: #{name}"}))
      _   -> send_resp(conn, 500, JSON.encode!(%{status: :error, message: "Error in deleting queue: #{name}"})) 
    end
  end

  match _ do
    send_resp(conn, 400, "Not found.")
  end

  defp create_queue %{"priorities" => p} do
    name = UUID.uuid4(:hex)
    {:ok, _pid} = Numerino.QueueManager.Transient.new_queue(name, p)
    {:ok, name, "transient", p}
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
    JSON.encode!( %{status: :ok, 
                    message: "Insert new object with the message: #{object} under the priority #{priority}", 
                    priority: priority, message: object})
  end
end

