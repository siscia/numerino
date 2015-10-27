defmodule Numerino.Repo do
  use Ecto.Repo, otp_app: :numerino, adapter: Sqlite.Ecto
end

defmodule Numerino.Db.Users do
  use Ecto.Model

  @primary_key {:id, :id, autogenerate: true}

  schema "user" do
    field :email, :string, uniq: true
    field :password, :string
    has_many :queue, Numerino.Db.Queues
    timestamps
  end
end

defmodule Numerino.Db.Queues do
  use Ecto.Model

  @primary_key {:id, :id, autogenerate: true}

  schema "queue" do
    field :name, :string
    belongs_to :user, Numerino.Db.Users
    has_many :priority, Numerino.Db.Priorities
    timestamps
  end
end

defmodule Numerino.Db.Priorities do
  use Ecto.Model

  @primary_key {:id, :id, autogenerate: true}

  schema "priority" do
    field :name, :string
    belongs_to :queue, Numerino.Db.Users
    has_many :job, NUmerino.Db.Jobs
    timestamps
  end
end

defmodule Numerino.Db.Jobs do
  use Ecto.Model
  
  @primary_key {:id, :id, autogenerate: true}
 
  schema "job" do
    field :message, :string
    field :served, Ecto.Time
    belongs_to :priority, Numerino.Db.Priorities 
    timestamps
  end
end
