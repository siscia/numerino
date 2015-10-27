defmodule Numerino.Repo.Migrations.AddQueuesTable do
  use Ecto.Migration

  def up do
    create table(:queue) do
      add :name, :string
      add :user_id, references(:user)
      timestamps
    end
  end
end
