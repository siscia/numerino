defmodule Dispenser do
  "
    Dispenser keep a single priority in a single queue.
  "

  defstruct mode: :push, elements: [], queue: nil, priority: nil, confirmed: false

  def start_link n, priority do
    {:ok, pid} = Agent.start_link(fn -> 
      %Dispenser{queue: n, priority: priority}
    end)
    Numerino.add_dispenser(n, priority, pid)
    {:ok, pid}
  end

  def confirm state do
    Agent.update(state, fn s -> %Dispenser{s | confirmed: true} end)
  end

  def push(state, new) do
    Agent.update(state, fn d -> do_push(d, new) end)
  end

  def do_push(%Dispenser{mode: :push, elements: e} = d, new) do
    %Dispenser{d | elements: [new | e]}
  end

  def do_push(%Dispenser{mode: :pop, elements: e} = d, new) do
    %Dispenser{mode: :push, elements: [new | Enum.reverse(e)]}
  end

  def pop(state) do
    Agent.get_and_update(state, fn d -> do_pop(d) end)
  end

  defp do_pop(%Dispenser{mode: :pop, elements: e}) do
    {e, %Dispenser{mode: :pop, elements: []}}
  end

  defp do_pop(%Dispenser{mode: :push, elements: e}) do
    {Enum.reverse(e), %Dispenser{mode: :pop, elements: []}}
  end

  defp do_pop(%Dispenser{elements: []} = d) do
    {[], %Dispenser{d | mode: :pop}}
  end
end
