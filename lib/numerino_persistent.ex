defmodule NumerinoPersistent do
  use GenServer
  
  def start_link :new, queue_id, user, priorities, callback, opts do
     GenServer.start_link(__MODULE__, {:new, queue_id, user, priorities, callback}, opts)
  end

  def start_link :existing, id, callback, opts do
    GenServer.start_link(__MODULE__, {:existing, id, callback}, opts)
  end

  def push n, priority, message do
    GenServer.call(n, {:push, priority, message})
  end

  def pop n do
    GenServer.call(n, :pop)
  end

  def get_queue_id n do
    GenServer.call(n, :get_queue_id)
  end

  def dispenser_update n, dispenser_name, dispenser_pid do
    GenServer.call(n, {:dispenser_update, dispenser_name, dispenser_pid})
  end

  def init {:new, queue_id, user, priorities, callback} do
    new_queue_query = Numerino.Db.Queues.Query.new
    Task.async(Numerino.Db.Batcher.task_function(nil, new_queue_query, [queue_id, user, :os.system_time]))
    {:ok, s} = DispenserPersistentSup.start_link
    list = priorities |> Enum.map( &to_string(&1) ) |>
    Enum.map(
      fn p ->
        new_priorities_query = Numerino.Db.Priorities.Query.new
        Task.async(Numerino.Db.Batcher.task_function(nil, new_priorities_query, [p, queue_id, :os.system_time]))
        {:ok, pid} = DispenserPersistentSup.start_dispenser s, self, {p, queue_id}
        {p, [], pid}
      end) 

    callback.(self, queue_id)
    {:ok, list}
  end

  def init {:existing, queue_id, callback} do
    {:ok, s} = DispenserPersistentSup.start_link
    priorities_from_queue_query = Numerino.Db.Priorities.Query.from_queue
    priorities = Numerino.Db.Batcher.query(Batcher, priorities_from_queue_query, [queue_id], nil)
    list = Enum.map(priorities,
      fn {p_id, p} -> 
        {:ok, pid} = DispenserPersistentSup.start_dispenser s, self, {p, p_id}
        {p, [], pid}
      end)
   
    callback.(self, queue_id)
    {:ok, list}
  end

  def handle_call {:push, priority, message}, _from, list do
    queue = List.keyfind(list, priority, 0)
    case queue do
      nil -> {:reply, {:error, :not_found_priority}, list}
      
     
      {priority, empty, dispenser} when empty == :EOF or empty == [] ->
          Task.async(fn -> result = DispenserPersistent.push(dispenser, message); {:batcher, nil, result} end);
          t = Task.async(DispenserPersistent, :peek, [dispenser, 100]);
          new_list = List.keyreplace(list, priority, 0, {priority, t, dispenser});
          {:reply, {:ok, {priority, message}}, new_list}
      
      {priority, _value, dispenser} ->
          Task.async(fn -> result = DispenserPersistent.push(dispenser, message); {:batcher, nil, result} end);
          {:reply, {:ok, {priority, message}}, list}
    end
  end

  def handle_call :pop, from, list do
    {list, value} = loop list
    case value do
      %{value: {job_id, mssg}, p_pid: p_pid} ->
          Task.async(fn -> :ok = DispenserPersistent.confirm(p_pid, job_id); {:confirm, :ok, from, {job_id, mssg}} end)
          {:noreply, list}
      :EOF -> {:reply, {:ok, :EOF}, list}
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
  defp loop_queue({p, [], p_pid}), do: {p, Task.async(DispenserPersistent, :peek, [p_pid, 100]), p_pid}

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
  defp find_value({p, %Task{} = t, p_pid} = q) do
    value = case Task.await(t) do
      [] -> :EOF
      [h|t] -> [h | t]
    end
    find_value({p, value, p_pid})
  end

  def handle_call {:dispenser_update, dispenser_name, dispenser_pid}, _from, list do
    {^dispenser_name, values, _old_pid} = List.keyfind(list, dispenser_name, 0)
    list = List.keyreplace(list, dispenser_name, 0, {dispenser_name, values, dispenser_pid})
    {:reply, :ok, list}
  end

  def handle_call :get_queue_id, _from, [{_p, _v, p_pid}|t] = list do
    queue_id = DispenserPersistent.get_queue_id p_pid
    {:reply, queue_id, list}
  end

  def handle_cast {:update, p_pid, ref, msggs}, list do
    queue = List.keyfind(list, p_pid, 2)
    list = case queue do
      {p, ^ref, ^p_pid} -> List.keyreplace(list, p_pid, 2, {p, msggs, p_pid})
      _ -> list
    end
    {:noreply, list}
  end

  def handle_info({_ref, {:confirm, :ok, from, {job_id, mssg}}}, state) do
    GenServer.reply(from, {:ok, {job_id, mssg}})
    {:noreply, state}
  end

  def handle_info({_ref, {:batcher, nil, result}}, state) do
    {:noreply, state}
  end

  def handle_info({_ref, {:batcher, from, result}}, state) do
    GenServer.reply(from, result)
    {:noreply, state}
  end

def handle_info {ref, mssg}, list do
    list = Enum.map(list, &find_list_with_ref({ref, mssg}, &1))
    {:noreply, list}
  end

  def handle_info {:DOWN, _ref, _type, _pid, _exit_value}, list do
    {:noreply, list}
  end

  def find_list_with_ref({ref1, mssg}, {p, %Task{ref: ref2}, p_pid} = q) do
    mssg = case mssg do
      [] -> :EOF
      [h|t] -> [h|t]
    end
    if(ref1 == ref2, do: {p, mssg, p_pid}, else: q)
  end
  def find_list_with_ref({_ref1, _mssg}, {_p, _value, _p_pid} = q), do: q

end
