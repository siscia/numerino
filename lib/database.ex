defmodule Numerino.Db do

  def get_path do
    %{path: p} = Application.get_env :numerino, Numerino.Db
    p
  end

  def connect path do
    {:ok, c} = :esqlite3.open(path)
    :ok = :esqlite3.exec('PRAGMA foreign_key = ON;', c)
    {:ok, c}
  end

  def connect do
    connect get_path
  end

  def last_rowid conn do
    [{n}] = :esqlite3.q('SELECT last_insert_rowid();', conn)
    n
  end

  def prepared_insert stat do
    case :esqlite3.step stat do
      :"$done" -> {:ok, :"$done"}
      error -> {:error, error}
    end
  end

end

defmodule Numerino.Db.Users do

  def create_table conn do
    query = 'CREATE TABLE IF NOT EXISTS
              users (user_id INTEGER PRIMARY KEY,
                     email TEXT,
                     password TEXT,
                     created_at TEXT DEFAULT CURRENT_TIMESTAMP);'
    :esqlite3.exec(query, conn)
  end

  defmodule Query do

    @new 'INSERT INTO users(email, password, created_at) values(?1, ?2, ?3)' 
    @auth 'SELECT password FROM users WHERE email = ?' 

    def new, do: @new
    def auth, do: @auth
    
#    def new conn, email, password do
#      pass = Comeonin.Bcrypt.hashpwsalt(password)
#      {:ok, stat} = :esqlite3.prepare('INSERT INTO users(email, password, created_at) values(?1, ?2, ?3)', conn)
#      :ok = :esqlite3.bind(stat, [email, pass, :os.system_time])
#      Numerino.Db.prepared_insert stat
#    end
#
#    def auth conn, email, password do
#      [{saved_pass}] = :esqlite3.q('SELECT password FROM users WHERE email = ?;',
#        [email], conn)
#      Comeonin.Bcrypt.checkpw(password, saved_pass)
#    end
#
  end

end

defmodule Numerino.Db.Queues do

  def create_table conn do
    query = 'CREATE TABLE IF NOT EXISTS
              queues (queue_id TEXT PRIMARY KEY,
                      user_id INTEGER,
                      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                      FOREIGN KEY (user_id) REFERENCES users(user_id))'
    :esqlite3.exec(query, conn)
  end

  defmodule Query do
   
    @new 'INSERT INTO queues(queue_id, user_id, created_at) VALUES(?1, ?2, ?3)' 
    @exists 'SELECT queues_id FROM queues WHERE queues_id = ?' 

    def new, do: @new
    def exists, do: @exists

#    def new conn, queue_id, user_id do
#      {:ok, stat} = :esqlite3.prepare('INSERT INTO queues(queue_id, user_id, created_at) VALUES(?1, ?2, ?3)', conn)
#      :ok = :esqlite3.bind(stat, [queue_id, user_id, :os.system_time])
#      Numerino.Db.prepared_insert stat
#    end
#
#    def exist conn, queue_id do
#      :esqlite3.q('SELECT queues_id FROM queues WHERE queues_id = ?', [queue_id], conn)
#    end
#
  end
end

defmodule Numerino.Db.Priorities do

  def create_table conn do
    query = "CREATE TABLE IF NOT EXISTS
              priorities (priority_id INTEGER PRIMARY KEY,
                          name TEXT,
                          queue_id TEXT,
                          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                          FOREIGN KEY(queue_id) REFERENCES queues(queue_id))"
    :esqlite3.exec(query, conn)
  end

  defmodule Query do

    @new 'INSERT INTO priorities(name, queue_id, created_at) VALUES(?1, ?2, ?3)' 
    @from_queue 'SELECT priority_id, name FROM priorities WHERE queue_id = ? ORDER BY priority_id ASC' 
    @get_queue_id 'SELECT queue_id FROM priorities WHERE priority_id = ?' 

    def new, do: @new
    def from_queue, do: @from_queue
    def get_queue_id, do: @get_queue_id

#    def new conn, name, queue_id do
#      {:ok, stat} = :esqlite3.prepare('INSERT INTO priorities(name, queue_id, created_at) VALUES(?1, ?2, ?3)', conn)
#      :ok = :esqlite3.bind(stat, [name, queue_id, :os.system_time])
#      Numerino.Db.prepared_insert stat
#    end
#
#    def from_queue conn, queue_id do
#      :esqlite3.q('SELECT priority_id, name FROM priorities WHERE queue_id = ? ORDER BY priority_id ASC', [queue_id], conn)
#    end
#
#    def get_queue_id conn, priority_id do
#      :esqlite3.q('SELECT queue_id FROM priorities WHERE priority_id = ?', [priority_id], conn)
#    end

  end

end

defmodule Numerino.Db.Jobs do
    
  def create_table conn do
    query = 'CREATE TABLE IF NOT EXISTS
              jobs (job_id INTEGER PRIMARY KEY,
                    message TEXT,
                    served INTEGER DEFAULT 0,
                    priority_id INTEGER,
                    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY(priority_id) REFERENCES priority(priority_id));'
    :esqlite3.exec(query, conn)
  end

  defmodule Query do

    @new 'INSERT INTO jobs(message, priority_id, created_at) VALUES(?1, ?2, ?3)' 
    @pop 'SELECT job_id, message FROM jobs WHERE served = 0 AND priority_id = ? ORDER BY job_id ASC LIMIT 1' 
    @peek 'SELECT job_id, message FROM jobs WHERE served = 0 AND priority_id = ?1 ORDER BY job_id ASC LIMIT ?2' 
    @confirm 'UPDATE jobs SET served = 1 WHERE job_id = ?'

    def new, do: @new
    def pop, do: @pop
    def peek, do: @peek
    def confirm, do: @confirm
#
#    def new conn, message, priority_id do
#      {:ok, stat} = :esqlite3.prepare('INSERT INTO jobs(message, priority_id, created_at) VALUES(?1, ?2, ?3)', conn)
#      :ok = :esqlite3.bind(stat, [message, priority_id, :os.system_time])
#      Numerino.Db.prepared_insert stat
#    end
#
#    def pop conn, priority do
#      [{job_id, message}] = :esqlite3.q('SELECT job_id, message FROM jobs WHERE served = 0 AND priority_id = ? ORDER BY job_id ASC LIMIT 1', [priority], conn)
#      {job_id, message}
#    end
#
#    def peek conn, priority, n do
#      :esqlite3.q('SELECT job_id, message FROM jobs WHERE served = 0 AND priority_id = ?1 ORDER BY job_id ASC LIMIT ?2', [priority, n], conn)
#    end
#
#    def confirm_send conn, job_id do
#      result = :esqlite3.exec('UPDATE jobs SET served = 1 WHERE job_id = ?', [job_id], conn)
#      case result do
#        :"$done" -> {:ok, job_id}
#        _ -> confirm_send conn, job_id
#      end
#    end
  end
end

defmodule Numerino.Db.Batcher do
  use GenServer

  def start_link opts \\ [] do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def add_job(server, query, argument) do
    GenServer.call(server, {:batch, query, argument})
  end

  def query(server, query, argument) do
    GenServer.call(server, {:query, query, argument})
  end

  def fire(server) do
    GenServer.call(server, :fire)
  end

  def auto_fire(server) do
    GenServer.call(server, :autofire)
  end

  def inspect(server) do
    GenServer.call(server, :inspect)
  end

  def task_function(from, query, args) do
    fn -> 
      result = Numerino.Db.Batcher.add_job(Batcher, query, args)
      {:batcher, from, result}
    end
  end

  def init(:ok) do
    {:ok, conn} = Numerino.Db.connect
    :erlang.start_timer(100, self, :autofire)
    {:ok, {conn, :queue.new}}
  end

  def handle_call({:batch, query, arguments}, from, {conn, queue}) do
    {:noreply, {conn, :queue.in({query, arguments, from}, queue)}}
  end

  def handle_call(:fire, _from, {conn, queue}) do
    do_write(conn, queue)
    {:reply, :ok, {conn, :queue.new}}
  end

  def handle_call(:autofire, _from, {conn, queue}) do
    do_write(conn, queue)
##    IO.inspect "Fire from here"
    :erlang.start_timer(500, self, :autofire)
    {:reply, :ok, {conn, :queue.new}}
  end

  def handle_call({:query, query, argument}, _from, {conn, queue}) do
    do_write(conn, queue)
    result = :esqlite3.q(query, argument, conn)
    {:reply, {:ok, result}, {conn, :queue.new}}
  end

  defp do_write(conn, queue) do
    queries = :queue.to_list(queue)
    ## IO.inspect queries
    if Enum.empty?(queries) do
      ## IO.puts '0'
      :ok
    else
      ## IO.inspect queries
      :ok = :esqlite3.exec('BEGIN;', conn)
      to_notify = Enum.map(queries, 
        fn {query, argument, from} -> 
          :"$done" = :esqlite3.exec(query, argument, conn);
          from
        end)

      :ok = :esqlite3.exec('COMMIT;', conn)
        Enum.map(to_notify, 
        fn from ->
          ## IO.inspect from
          case from do
            from when is_pid(from) -> GenServer.reply(from, :ok) 
            {from, ref} when is_pid(from) -> GenServer.reply({from, ref}, :ok)
            _ -> :ok
          end
        end)
      ## IO.write ">>> "
      ## IO.puts length(queries)
      :ok
    end
  end

  def  handle_call(:inspect, _from, value) do
    {:reply, value, value}
  end

  def handle_info({:timeout, _ref, :autofire}, {conn, queue}) do
    do_write(conn, queue)
    :erlang.start_timer(1010, self, :autofire)
    {:noreply, {conn, :queue.new}}
  end

end

