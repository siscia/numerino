
defmodule DispenserPersintentSup do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok)
  end

  def init :ok do
    children = [
      worker(DispenserPersintent, [])
    ]
  
    supervise(children, strategy: :simple_one_for_one)
  end

  def start_dispenser sup, n, {priority, id_prior} do
    {:ok, conn} = Numerino.Db.connect
    Supervisor.start_child(sup, [n, {priority, id_prior}, conn])
  end

end

defmodule DispenserPersintent do
  use GenServer

  defstruct db: nil, priority: nil, ack: false, occupied: false, cache: []

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

  def ack server do
    GenServer.call(server, :ack)
  end

  def confirm server, job_id do
    GenServer.call(server, {:confirm, job_id})
  end

  def init {:ok, n, {p, id_p}, db} do
    #Numerino.add_dispenser(n, p, self)
    {:ok, %DispenserPersintent{db: db, priority: id_p}}
  end

  def handle_call :pop, _from, %DispenserPersintent{db: db, priority: priority} = d do
    {job_id, message} = Numerino.Db.Jobs.Query.pop(db, priority)
    DispenserPersintent.confirm_send(self, job_id)
    {:reply, message, d}
  end

  def handle_call {:push, message}, _from, 
                  %DispenserPersintent{db: db, 
                                       priority: priority} = d do
    {:ok, _} = Numerino.Db.Jobs.Query.new db, message, priority
    {:reply, :ok, d}
  end

  def handle_call :ack, _from, %DispenserPersintent{} = d do
    {:reply, :confirmed, %DispenserPersintent{d | ack: true}}
  end

  def handle_call {:confirm, job_id}, _from, %DispenserPersintent{db: db} = d do
    {:ok, _} = Numerino.Db.Jobs.Query.confirm_send(db, job_id)
    {:reply, :ok, d}
  end

  def handle_call {:peek, n}, _from, %DispenserPersintent{db: db, priority: p} = d do
    mssg = case Numerino.Db.Jobs.Query.peek(db, p, n) do
        [] -> :EOF
        [h|t] -> [h|t]
      end
    IO.inspect mssg
    {:reply, mssg, d}
    end

end
