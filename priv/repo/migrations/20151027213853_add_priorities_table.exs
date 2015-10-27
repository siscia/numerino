defmodule Numerino.Repo.Migrations.AddPrioritiesTable do
  use Ecto.Migration

  def up do
    create table(:priority) do
      add :name, :string
      add :queue_id, references(:queue)      
    end
  end
end
