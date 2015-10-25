defmodule Numerino do
  use GenServer

  defstruct queue: HashDict.new

  def start_link(priorities, callback, opts \\ []) do
    GenServer.start_link(__MODULE__, {:ok, callback, priorities}, opts)
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

  def init({:ok, callback, priorities}) do
    callback.(self)
    list = Enum.into(priorities, [], 
      fn priority -> 
        {:ok, pid} = Dispenser.start;
        Process.monitor(pid); 
        {priority, [], pid} 
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

  defp do_single_pop {_priority, [h | t], _pid} do
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

  def push(state, new) do
    Agent.update(state, fn d -> do_push(d, new) end)      
  end

  def do_push %Dispenser{mode: :push, elements: e} = d, new do
    %Dispenser{d | elements: [new | e]}
  end

  def do_push %Dispenser{mode: :pop, elements: e} = d, new do
    %Dispenser{mode: :push, elements: [new | Enum.reverse(e)]}
  end
  
  def pop(state) do
    Agent.get_and_update(state, fn d -> do_pop(d) end)
  end

  defp do_pop %Dispenser{mode: :pop, elements: e} do
    {e, %Dispenser{mode: :pop, elements: []}}
  end

  defp do_pop %Dispenser{mode: :push, elements: e} do
    {Enum.reverse(e), %Dispenser{mode: :pop, elements: []}}
  end

  defp do_pop %Dispenser{elements: []} = d do
    {[], %Dispenser{d | mode: :pop}}
  end
end

