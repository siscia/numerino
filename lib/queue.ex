defmodule Numerino.Queue do
  
  def new(priorities) do
    Enum.map(priorities, fn p 
      -> {p, :queue.new}
    end)
  end

  def push(list, priority, message) do
    case List.keyfind(list, priority, 0) do
      nil -> 
        {{:error, :not_found_priority}, list}
      {^priority, queue} ->
        new_list = List.keyreplace(list, priority, 0, {priority, :queue.in(message, queue)});
        {{:ok, {priority, message}}, new_list}
    end
  end

  def pop(list) do
    do_pop = fn {p, queue}, acc ->
      case acc do
        :EOF -> case :queue.out(queue) do
                  {:empty, queue} -> {{p, queue}, :EOF}
                  {{:value, message}, new_queue} -> {{p, new_queue}, {p, message}}
                end
        _ -> {{p, queue}, acc}
      end
    end
    {new_list, mssg} = Enum.map_reduce(list, :EOF, do_pop)
    case mssg do
      :EOF -> {{:ok, :EOF}, new_list}
      {_, _} -> {{:ok, mssg}, new_list}
    end
  end
end
