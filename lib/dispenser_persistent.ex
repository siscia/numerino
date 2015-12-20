
defmodule DispenserPersistentSup do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok)
  end

  def init :ok do
    children = [
      worker(DispenserPersistent, [])
    ]
  
    supervise(children, strategy: :simple_one_for_one)
  end

  def start_dispenser sup, n, {priority, id_prior} do
    {:ok, conn} = Numerino.Db.connect
    Supervisor.start_child(sup, [n, {priority, id_prior}, conn])
  end

end

defmodule DispenserPersistent do
  use GenServer

  defstruct db: nil, priority: nil, batched: []

  def start_link n, {p, id_p}, db, opts \\ [] do
    GenServer.start_link(__MODULE__, {:ok, n, {p, id_p}, db}, opts) 
  end

  def pop server do
    GenServer.call(server, :pop)
  end

  def push server, message do
    GenServer.call(server, {:push, message})
  end

  def peek server, n do
    GenServer.call(server, {:peek, n})
  end

  def confirm server, job_id do
    GenServer.call(server, {:confirm, job_id})
  end

  def get_queue_id server do
    GenServer.call(server, :get_queue_id)
  end

  def confirm_push server, ref do
    GenServer.call(server, {:confirm_push, ref})
  end

  def init {:ok, n, {p, id_p}, db} do
    Task.async(NumerinoPersistent, :dispenser_update, [n, p, self])
    {:ok, %DispenserPersistent{db: db, priority: id_p}}
  end

  def handle_call {:push, message}, from, 
                  %DispenserPersistent{priority: priority} = d do
    query = Numerino.Db.Jobs.Query.new
    Task.async(Numerino.Db.Batcher.task_function(from, query, [message, priority, :os.system_time]))
    {:noreply, d}
  end

  def handle_call {:confirm, job_id}, from, %DispenserPersistent{db: db} = d do
    query = Numerino.Db.Jobs.Query.confirm
    Task.async(Numerino.Db.Batcher.task_function(from, query, [job_id]))
    {:noreply, d}
  end

  def handle_call {:peek, n}, _from, %DispenserPersistent{db: db, priority: p} = d do
    query = Numerino.Db.Jobs.Query.peek
    {:ok, result} = Numerino.Db.Batcher.query(Batcher, query, [p, n])
    {:reply, result, d}
    end

  def handle_call :get_queue_id, _from, %DispenserPersistent{db: db, priority: p} = d do
    [{queue_id}] = Numerino.Db.Priorities.Query.get_queue_id db, p
    {:reply, queue_id, d} 
  end

  def handle_info({_ref, {:batcher, from, result}}, d) do
    if from != nil, do: GenServer.reply(from, result)
    {:noreply, d}
  end

  def handle_info {ref, :ok}, %DispenserPersistent{} = d do
    {:noreply, d}
  end

  def handle_info {:DOWN, _, _, _, _}, d do
    {:noreply, d}
  end

end
