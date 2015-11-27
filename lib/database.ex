defmodule Numerino.Repo do
  use Ecto.Repo, otp_app: :numerino, adapter: Sqlite.Ecto
end

defmodule Numerino.Db do

  def create_connection path do
    {:ok, c} = :esqlite3.open(path)
    :ok = :esqlite3.exec('PRAGMA foreign_key = ON;', c)
    {:ok, c}
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
    def new conn, email, password do
      pass = Comeonin.Bcrypt.hashpwsalt(password)
      {:ok, stat} = :esqlite3.prepare('INSERT INTO users(email, password, created_at) values(?1, ?2, ?3)', conn)
      :ok = :esqlite3.bind(stat, [email, pass, :os.system_time])
      Numerino.Db.prepared_insert stat
    end

    def auth conn, email, password do
      [{saved_pass}] = :esqlite3.q('SELECT password FROM users WHERE email = ?;',
        [email], conn)
      Comeonin.Bcrypt.checkpw(password, saved_pass)
    end

  end

end

defmodule Numerino.Db.Queues do

  def create_table conn do
    query = 'CREATE TABLE IF NOT EXISTS
              queues (queues_id INTEGER PRIMARY KEY,
                      name TEXT,
                      user_id INTEGER,
                      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                      FOREIGN KEY (user_id) REFERENCES users(user_id))'
    :esqlite3.exec(query, conn)
  end

  defmodule Query do
    
    def new conn, name, user_id do
      {:ok, stat} = :esqlite3.prepare('INSERT INTO queues(name, user_id, created_at) VALUES(?1, ?2, ?3)', conn)
      :ok = :esqlite3.bind(stat, [name, user_id, :os.system_time])
      Numerino.Db.prepared_insert stat
    end
  end
end

defmodule Numerino.Db.Priorities do

  def create_table conn do
    query = "CREATE TABLE IF NOT EXISTS
              priorities (priority_id INTEGER PRIMARY KEY,
                          name TEXT,
                          queue_id INTEGER,
                          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                          FOREIGN KEY(queue_id) REFERENCES queues(queue_id))"
    :esqlite3.exec(query, conn)
  end

  defmodule Query do
    def new conn, name, queue_id do
      {:ok, stat} = :esqlite3.prepare('INSERT INTO priorities(name, queue_id, created_at) VALUES(?1, ?2, ?3)', conn)
      :ok = :esqlite3.bind(stat, [name, queue_id, :os.system_time])
      Numerino.Db.prepared_insert stat
    end
  end

end

defmodule Numerino.Db.Jobs do
    
  def create_table conn do
    query = 'CREATE TABLE IF NOT EXISTS
              jobs (job_id INTEGER PRIMARY KEY,
                    message TEXT,
                    served INTEGER DEFAULT -1,
                    priority_id INTEGER,
                    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY(priority_id) REFERENCES priority(priority_id));'
    :esqlite3.exec(query, conn)
  end

  defmodule Query do
    def new conn, message, priority_id do
      {:ok, stat} = :esqlite3.prepare('INSERT INTO jobs(message, priority_id, created_at) VALUES(?1, ?2, ?3)', conn)
      :ok = :esqlite3.bind(stat, [message, priority_id, :os.system_time])
      Numerino.Db.prepared_insert stat
    end
  end

end

