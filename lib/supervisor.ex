defmodule Numerino.Supervisor do
  use Supervisor

  def start_link(_) do
    Supervisor.start_link(__MODULE__, [], name: :supervisor)   
  end

  def init(_) do
    processes = [
      worker(Numerino.QueueAddress, []),
      supervisor(Numerino.QueueManager.Transient, []),
      worker(Numerino.Db.Batcher, [[name: Batcher]])
    ]
    supervise(processes, strategy: :rest_for_one)
  end
end

defmodule Numerino.QueueManager.Transient do
  use Supervisor

  @self Numerino.QueueManager.Transient

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, :ok, [name: @self] ++ opts)
  end

  def init(:ok) do
    spawn Numerino.QueueManager.Transient, :restart_old_queues, []
    process = [
      worker(Numerino.Transient, [])
    ]
    supervise(process, strategy: :simple_one_for_one)
  end

  defp generate_callback(name, priorities) do
    fn p ->
        Numerino.QueueAddress.follow(p, name, priorities)
    end
  end

  def new_queue(name, priorities) do
    callback = generate_callback(name, priorities)
    {:ok, _p} = Supervisor.start_child(@self, [priorities, callback])
  end

  defp do_restart_old_queue {_name, _pid, :persistent}, acc do
    acc
  end

  defp do_restart_old_queue({name, _pid, priorities}, acc) do
    new_queue(name, priorities)
    acc + 1
  end

  def restart_old_queues do
    :ets.foldl(&do_restart_old_queue/2, 0, Numerino.QueueAddress)
  end
end

defmodule Numerino.QueueAddress do
  use GenServer

  @table_name Numerino.QueueAddress
  @server_name QueueAddressServer

  def start_link(opts \\ [name: @server_name]) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def follow(pid, name, priorities) do
    GenServer.call(@server_name, {:follow, pid, name, priorities})
  end

  def init(:ok) do
    @table_name = :ets.new(@table_name,
                  [:named_table, {:read_concurrency, true}])
    {:ok, @table_name}
  end

  def handle_call({:follow, pid, name, priorities}, _from, state) do
    :ets.insert(@table_name, {name, pid, priorities})
    {:reply, name ,state}
  end
end
