
defmodule Numerino.Timer do
  use GenServer

  def start_link(free_time) do
    GenServer.start_link(__MODULE__, {:ok, free_time}, [name: Timer])
  end

  def start_timer(server) do
    GenServer.call(server, :start_timer)
  end

  def wait(server) do
    GenServer.call(server, :wait)
  end

  def add_target(server, order, pid) do
    GenServer.call(server, {:add_target, order, pid})
  end

  def init({:ok, free_time}) do
    {:ok, {free_time, []}}
  end

  def handle_call(:start_timer, _from, {free_time, list}) do
    
  end

  def handle_call({:add_target, order, pid}, from, {free_time, list}) do
    [smaller, bigger] = Enum.partition(list, fn {ord, pid} -> ord < order end)
    bigger = case bigger do
      [{^order, _pid}| t] -> [{order, pid} | t] 
      _ -> [{order, pid}] ++ bigger
    end
    updated_list = smaller ++ bigger
    {:reply, :ok, {free_time, updated_list}}
  end

end
