defmodule Test do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, :ok)
  end

  def init :ok do
    {:ok, 1}
  end

  def create_task n do
    GenServer.call(n, :create_task)
  end

  def read_task n, t do
    GenServer.call(n, {:read_task, t})
  end

  def read_state n do
    GenServer.call(n, :read)
  end

  def handle_call :create_task, _from, v do
    t = Task.async(fn -> 3 * v end)
    {:reply, t, v}
  end

  def handle_call {:read_task, t}, _from, v do
    i = Task.await(t)
    {:reply, :ok, i}
  end

  def handle_call :read, _from, v do
    {:reply, v, v}
  end

  def handle_info {ref, mssg}, v do
    {:noreply, mssg}
  end

  def handle_info {:DOWN, _ref, _p, _pid, _status}, v do
    {:noreply, v}
  end

end
