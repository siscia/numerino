defmodule Numerino.Repo.Migrations.AddUsersTable do
  use Ecto.Migration

  def up do
    create table(:user) do
      add :email, :string
      add :password, :string
      timestamps
    end
  end
end
