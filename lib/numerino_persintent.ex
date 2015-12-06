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
    {:ok, list}
  end

  def init {:old, queue_id, callback} do
    {:ok, conn} = Numerino.Db.connect
    {:ok, s} = DispenserPersintentSup.start_link
    priorities = Numerino.Db.Priorities.Query.from_queue conn, queue_id
    IO.inspect priorities
    list = Enum.map(priorities,
      fn {p_id, p} -> 
        {:ok, pid} = DispenserPersintentSup.start_dispenser s, self, {p, p_id}
        {p, [], pid}
      end)
    callback.(self)
    {:ok, list}
  end

  def handle_call {:push, priority, message}, _from, list do
    queue = List.keyfind(list, priority, 0)
    case queue do
      nil -> {:reply, {:error, :not_found_priority}, list}
      
      {priority, empty, dispenser} when empty == :EOF or empty == [] ->
          DispenserPersintent.push dispenser, message;
          t = Task.async(DispenserPersintent, :peek, [dispenser, 5]);
          new_list = List.keyreplace(list, priority, 0, {priority, t, dispenser});
          {:reply, {:ok, {priority, message}}, new_list}
      
      {priority, _value, dispenser} ->
          DispenserPersintent.push dispenser, message;
          {:reply, {:ok, {priority, message}}, list}
    end
  end

  def handle_call :pop, _from, list do
    {list, value} = loop list
    case value do
      %{value: {job_id, mssg}, p_pid: p_pid} ->
          :ok = DispenserPersintent.confirm p_pid, job_id
          {:reply, {job_id, mssg}, list}
      :EOF -> {:reply, value, list}
    end
  end
 
  defp loop list do
    {list, value} =  Enum.map(list, &loop_queue/1)
                  |> Enum.map_reduce(:continue, &keep_first/2)
    case value do
      {:stop, actual_value, p_pid} -> {list, %{value: actual_value, p_pid: p_pid}}
      :continue -> {list, :EOF}
    end
  end

  defp loop_queue({_p, :EOF, _p_pid} = q), do: q
  defp loop_queue({_p, [_h|_t], _p_pid} = q), do: q
  defp loop_queue({_p, %Task{}, _p_pid} = q), do: q
  defp loop_queue({p, [], p_pid}), do: {p, Task.async(DispenserPersintent, :peek, [p_pid, 5]), p_pid}

  defp keep_first queue, :continue do
    case find_value queue do
      {false, q} -> {q, :continue}
      {value, p_pid, q} -> {q, {:stop, value, p_pid}}
    end
  end
  defp keep_first(queue, {:stop, value, p_pid}), do: {queue, {:stop, value, p_pid}}

  defp find_value({_p, :EOF, _p_pid} = q), do: {false, q}
  defp find_value({_p, [], _p_pid} = q), do: {false, q}
  defp find_value({p, [h|t], p_pid}), do: {h, p_pid, {p, t, p_pid}}
  defp find_value({p, %Task{} = t, p_pid} = q), do: find_value({p, Task.await(t), p_pid})

  def handle_cast {:update, p_pid, ref, msggs}, list do
    queue = List.keyfind(list, p_pid, 2)
    list = case queue do
      {p, ^ref, ^p_pid} -> List.keyreplace(list, p_pid, 2, {p, msggs, p_pid})
      _ -> list
    end
    {:noreply, list}
  end

  def handle_info {ref, mssg}, list do
    list = Enum.map(list, &find_list_with_ref({ref, mssg}, &1))
    {:noreply, list}
  end
 
  def handle_info {:DOWN, _ref, _type, _pid, _exit_value}, list do
    {:noreply, list}
  end

  def find_list_with_ref({ref1, mssg}, {p, %Task{ref: ref2}, p_pid} = q) do
    if(ref1 == ref2, do: {p, mssg, p_pid}, else: q)
  end
  def find_list_with_ref({_ref1, _mssg}, {_p, _value, _p_pid} = q), do: q

end
