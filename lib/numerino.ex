
defmodule DispenserSup do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok)
  end

  def init :ok do
    children = [
      worker(Dispenser, [])
    ]

    supervise(children, strategy: :simple_one_for_one)
  end

  def start_dispenser sup, n, priority do
    Supervisor.start_child(sup, [n, priority])
  end

end

defmodule Numerino.Transient do
  use GenServer

  def start_link(priorities, callback, opts \\ []) do
    GenServer.start_link(__MODULE__, {:ok, callback, priorities}, opts)
  end

  def push(n, priority, message) do
    GenServer.call(n, {:push, priority, message})
  end

  def pop(n) do
    GenServer.call(n, :pop)
  end

  def inspect(numerino) do
    GenServer.call(numerino, :inspect)
  end

  def init({:ok, callback, priorities}) do
    callback.(self)
    list = Enum.map(priorities, fn p 
      -> {p, :queue.new}
      end)
    {:ok, list}
  end

  def handle_call({:push, priority, message}, _from, list) do

    case List.keyfind(list, priority, 0) do
      nil -> {:reply, {:error, :not_found_priority}, list}
      {^priority, queue} -> {:reply, {:ok, {priority, message}}, 
                            List.keyreplace(list, priority, 0, {priority, :queue.in(message, queue)})}
    end
  end

  def handle_call(:pop, _from, list) do
    do_pop = fn {p, queue}, acc ->
      case acc do
        :EOF -> case :queue.out(queue) do
                  {:empty, queue} -> {{p, queue}, :EOF}
                  {{:value, message}, new_queue} -> {{p, new_queue}, {p, message}}
                end
        _ -> {{p, queue}, acc}
      end
    end
    {list, mssg} = Enum.map_reduce(list, :EOF, do_pop)
    {:reply, {:ok, mssg}, list}
  end

  def handle_call(:inspect, _from, list) do
    {:reply, list, list}
  end

end
