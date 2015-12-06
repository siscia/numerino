defmodule NumerinoPersitent do
  use GenServer

  def start_link_new user, priorities, callback, opts \\ [] do
     GenServer.start_link(__MODULE__, {:new, user, priorities, callback}, opts)
  end

  def start_link_existing id, callback, opts \\ [] do
    GenServer.start_link(__MODULE__, {:old, id, callback}, opts)
  end

  def push n, priority, message do
    GenServer.call(n, {:push, priority, message})
  end

  def pop n do
    GenServer.call(n, :pop)
  end

  def update n, priority, ref, msggs do
    GenServer.cast(n, {:update, priority, ref, msggs})
  end

  def peek_dispenser n, priority, ref do
    GenServer.cast(n, {:peek_dispenser, priority, ref})
  end

  def init {:new, user, priorities, callback} do
    {:ok, conn} = Numerino.Db.connect
    {:ok, _} = Numerino.Db.Queues.Query.new conn, '', user
    queue_id = Numerino.Db.last_rowid conn
    {:ok, s} = DispenserPersintentSup.start_link
    list = Enum.map(priorities,
      fn p ->
        {:ok, _} = Numerino.Db.Priorities.Query.new conn, p, queue_id
        {:ok, pid} = DispenserPersintentSup.start_dispenser s, self, {p, Numerino.Db.last_rowid(conn)}
        {p, [], pid}
      end)
    callback.(self)
    {:ok, {list, s}}
  end

  def init {:old, id, callback} do
    callback.(self)
  end

  def handle_call {:push, priority, message}, _from, {list, s} do
    queue = List.keyfind(list, priority, 0)
    case queue do
      nil -> {:reply, {:error, :not_found_priority}, {list, s}}
      {priority, _value, dispenser} -> DispenserPersintent.push dispenser, message;
                                       new_list = List.keyreplace(list, priority, 0, {priority, Task.async(fn -> DispenserPersintent.peek(dispenser, 5) end), dispenser});
                                       {:reply, {:ok, {priority, message}}, {new_list, s}}
    end
  end

  def handle_call :pop, _from, {list, s} do
    {list, value} = loop list
    {:reply, value, {list, s}}
  end
 
  defp loop list do
    {list, value} =  Enum.map(list, &loop_queue/1)
                  |> Enum.map_reduce(:continue, &keep_first/2)
    IO.inspect value
    case value do
      {:stop, actual_value} -> {list, actual_value}
      :continue -> {list, :EOF}
    end
  end

  defp loop_queue({_p, :EOF, _p_pid} = q), do: q
  defp loop_queue({_p, [_h|_t], _p_pid} = q), do: q
  defp loop_queue({_p, %Task{}, _p_pid} = q), do: q
  defp loop_queue({p, [], p_pid}), do: {p, Task.async(DispenserPersintent, :peek, [p_pid, 5]), p_pid}

  defp keep_first queue, :continue do
    IO.inspect queue
    case find_value queue do
      {false, q} -> {q, :continue}
      {value, q} -> {q, {:stop, value}}
    end
  end
  defp keep_first(queue, {:stop, value}), do: {queue, {:stop, value}}

  defp find_value({_p, :EOF, _p_pid} = q), do: {false, q}
  defp find_value({_p, [], _p_pid} = q), do: {false, q}
  defp find_value({p, [h|t], p_pid}), do: {h, {p, t, p_pid}}
  defp find_value({p, %Task{} = t, p_pid} = q) do
    IO.puts "find_value con task"
    value = Task.await(t)
    IO.inspect value
    find_value({p, value, p_pid});
  end

  def handle_cast {:update, p_pid, ref, msggs}, {list, s} do
    IO.puts ":update with messagges"
    queue = List.keyfind(list, p_pid, 2)
    list = case queue do
      {p, ^ref, ^p_pid} -> List.keyreplace(list, p_pid, 2, {p, msggs, p_pid})
      _ -> list
    end
    {:noreply, {list, s}}
  end

  def handle_cast {:peek_dispenser, p, ref}, {list, s} do
    IO.puts ":peek_dispenser: #{p}"
    queue = List.keyfind(list, p, 0)
    list = case queue do
      {_p, _v, p_pid} -> DispenserPersintent.peek p_pid, self, 5, ref;
                         List.keyreplace(list, p, 0, {p, ref, p_pid})
      nil -> list
    end
    {:noreply, {list, s}}
  end

end
