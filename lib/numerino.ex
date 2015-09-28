defmodule Numerino do
  use GenServer

  defstruct queue: HashDict.new

  def start_link(priorities, opts \\ []) do
    GenServer.start_link(__MODULE__, {:ok, priorities}, opts)
  end

  def push(n, priority, message) do
    GenServer.call(n, {:push, priority, message})
  end

  def pop(n) do
    GenServer.call(n, :pop)
  end

  def inspect numerino do
    GenServer.call(numerino, :inspect)
  end

  def init({:ok, priorities}) do
    list = Enum.into(priorities, [], 
      fn priority -> 
        {:ok, pid} = Dispenser.start;
        Process.monitor(pid); 
        {priority, :EOF, pid} 
      end)
    {:ok, list}
  end

  def handle_call({:push, priority, message}, _from, list) do
    {_priority, _value, dispenser} = List.keyfind(list, priority, 0)
    Dispenser.push(dispenser, message)
    {:reply, {:ok, {priority, message}}, list}
  end

  defp do_single_pop {_priority, :EOF, pid} do
    {Dispenser.pop(pid), Dispenser.pop(pid)}
  end

  defp do_single_pop {_priority, value, pid} do
    {value, Dispenser.pop(pid)}
  end

  defp update_value({priority, _old_value, pid}, new_value) do
    {priority, new_value, pid}
  end

  defp loop_priority([{priority, _value, _pid} = element | next], acc) do
    case do_single_pop element do
      {:EOF, _} -> loop_priority(next, [element | acc])
      {value, next_value} -> {{priority, value}, Enum.concat(Enum.reverse([ update_value(element, next_value) | acc]), next)}
    end
  end

  defp loop_priority([], acc) do
    {:EOF, Enum.reverse(acc)}
  end 

  def handle_call(:pop, _from, list) do
    {value, list} = loop_priority(list, [])
    {:reply, {:ok, value}, list}
  end

  def handle_call(:inspect, _from, dict) do
    {:reply, dict, dict}
  end

  def handle_info {:DOWN, _ref, _proc, from, _reason}, list do
    {priority, value, _pid} = List.keyfind list, from, 2
    {:ok, new_pid} = Dispenser.start
    Process.monitor(new_pid)
    {:noreply, List.keyreplace(list, from, 2, {priority, value, new_pid})}
  end
end


defmodule Dispenser do

  defstruct mode: :push, elements: []

  def start() do
    Agent.start(fn -> %Dispenser{} end)
  end

  def do_push(%Dispenser{mode: m, elements: e}, new) do
    case m do
      :push -> %Dispenser{mode: m, elements: [new | e]}
      :pop -> %Dispenser{mode: :push, elements: [new | Enum.reverse(e)]}
    end
  end

  def push(state, new) do
    Agent.update(state, fn d -> do_push(d, new) end)      
  end

  defp do_pop %Dispenser{mode: m, elements: [h | t] = e} = d do
    case m do
      :pop -> {h, %Dispenser{d | elements: t }}
      :push -> [h | t] = Enum.reverse(e);
               {h, %Dispenser{elements: t, mode: :pop}}
    end
  end

  defp do_pop %Dispenser{elements: []} = d do
    {:EOF, %Dispenser{d | mode: :pop}}
  end

  def pop(state) do
    Agent.get_and_update(state, fn d -> do_pop(d) end)
  end
end 
