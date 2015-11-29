
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

defmodule Numerino do
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

  def add_dispenser(n, priority, pid) do
    GenServer.cast(n, {:add_dispenser, priority, pid})
  end

  def inspect(numerino) do
    GenServer.call(numerino, :inspect)
  end

  def init({:ok, callback, priorities}) do
    callback.(self)
    {:ok, s} = DispenserSup.start_link
    list = Enum.map(priorities,
      fn priority ->
        DispenserSup.start_dispenser(s, self, priority);
        {priority}
      end)
    {:ok, {list, s}}
  end

  def handle_call({:push, priority, message}, _from, {list, s}) do
    {_priority, _value, dispenser} = List.keyfind(list, priority, 0)
    case dispenser do
      nil -> {:reply, {:error, :not_found_priority}, {list, s}}
      _ -> Dispenser.push(dispenser, message);
           {:reply, {:ok, {priority, message}}, {list, s}}
    end
  end

  defp do_single_pop({_priority, :EOF, pid}) do
    {Dispenser.pop(pid), Dispenser.pop(pid)}
  end

  defp do_single_pop({_priority, [h | t], _pid}) do
    {h, t}
  end

  defp update_value({priority, _old_value, pid}, new_value) do
    {priority, new_value, pid}
  end

  defp regenerate_list(priority, next_value, pid, next_disp, acc_disp) do
    [{priority, next_value, pid} | acc_disp]
    |> Enum.reverse
    |> Enum.concat(next_disp)
  end

  defp loop_priority([{priority, [h | t], pid} | next], acc) do
    {{priority, h}, regenerate_list(priority, t, pid, next, acc)}
  end

  defp loop_priority([{priority, [], pid} = e | next], acc) do
    case Dispenser.pop(pid) do
      [h | t] -> {{priority, h}, regenerate_list(priority, t, pid, next, acc)}
      [] -> loop_priority(next, [e | acc])
    end
  end

  defp loop_priority([], acc) do
    {:EOF, Enum.reverse(acc)}
  end

  def handle_call(:pop, _from, {list, s}) do
    {value, list} = loop_priority(list, [])
    {:reply, {:ok, value}, list}
  end

  def handle_call(:inspect, _from, {list, s}) do
    {:reply, {list, s}, {list, s}}
  end

  def handle_cast({:add_dispenser, priority, pid}, {list, s}) do
    new_list = List.keyreplace(list, priority, 0, {priority, [], pid})
    Dispenser.confirm(pid)
    {:noreply, {new_list, s}}
  end

end
