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
    {:ok, Numerino.Queue.new(priorities)}
  end

  def handle_call({:push, priority, message}, _from, list) do
    case Numerino.Queue.push(list, priority, message) do
      {:ok, new_list} ->
        {:reply, {:ok, {priority, message}}, new_list}
      {:error, :not_found_priority} ->
        {:reply, {:error, :not_found_priority}, list}
    end
  end    

  def handle_call(:pop, _from, list) do
    case Numerino.Queue.pop(list) do
      {{:value, {priority, message}}, new_list} ->
        {:reply, {:ok, {priority, message}}, new_list}
      {:empty, new_list} ->
        {:reply, {:ok, :EOF}, new_list}
    end
  end

  def handle_call(:inspect, _from, list) do
    {:reply, list, list}
  end

end
