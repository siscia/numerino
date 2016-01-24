defmodule Numerino.Transient do
  def start_link(priorities, callback, opts \\ []) do
    Agent.start_link(fn ->
                        callback.(self)
                        Numerino.Queue.new(priorities)
                     end, opts)
  end

  def push(n, priority, message) do
    Agent.get_and_update(n, Numerino.Queue, :push, [priority, message])
  end

  def pop(n) do
    Agent.get_and_update(n, Numerino.Queue, :pop, [])
  end

  def inspect(n) do
    Agent.get(n, fn state -> state end)
  end
end
