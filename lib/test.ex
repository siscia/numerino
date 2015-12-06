defmodule Test do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, :ok)
  end

  def init :ok do
    {:ok, 1}
  end

  def t n do
    GenServer.call(n, :p)
  end

  def rt n, t do
    GenServer.call(n, {:r, t})
  end

  def handle_call :p, _from, v do
    t = Task.async(fn -> 3 * v end)
    {:reply, t, v}
  end

  def handle_call {:r, t}, _from, v do
    i = Task.await(t)
    {:reply, :ok, i}
  end

  def handle_info {ref, mssg}, v do
    {:noreply, v + mssg}
  end

  def handle_info {:DOWN, _ref, _p, _pid, _status}, v do
    {:noreply, v}
  end

end
