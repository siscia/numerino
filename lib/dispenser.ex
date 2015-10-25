defmodule Dispenser do
  defstruct mode: :push, elements: []

  def start do
    Agent.start(fn -> %Dispenser{} end)
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
