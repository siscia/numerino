defmodule Numerino.Persistent do
  use GenServer

  def start_link(:new, name, priorities, callback, opts // []) do
    GenServer.start_link(__MODULE__, {:new, name, priorities, callback}, opts)
  end

  def start_link(:existing, name, callback, opts // []) do
    GenServer.start_link(__MODULE__, {:existing, name, callback}, opts)
  end

  def init(:new, name, priorities, callback) do
    new_queue_query = Numerino.Db.Queues.new
    new_priority_query = Numerino.Db.Priorities.new
    Task.async(Numerino.Db.Batcher, :add_job, [Batcher, new_queue_query, [name, 1, :os.system_time]])
    Enum.map(priorities, fn p -> 
      Task.async(Numerino.Db.Batcher, :add_job, [Batcher, new_priority_query, [p, name, :os.system_time]])    
    end)
    callback.(self)
    {:ok, Numerino.Queue.new(priorities)}
  end

  def init(:existing, name, callback) do

  end


end
