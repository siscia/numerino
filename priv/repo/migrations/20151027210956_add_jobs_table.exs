defmodule Numerino.Repo.Migrations.AddJobsTable do
  use Ecto.Migration

  def up do
    create table(:job) do
      add :priority, :string
      add :message, :string
      add :served, :integer
      add :priority_id, references(:priority)
      timestamps
    end
  end
end
