# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :numerino, Numerino.Db,
  %{:path => ':memory:'}

config :kernel,
    inet_dist_listen_min: 5000,
    inet_dist_listen_max: 5000

#config :numerino, Numerino.Repo,
#  adapter: Ecto.Adapters.Postgres,
#  database: "numerino_repo",
#  username: "user",
#  password: "pass",
#  hostname: "localhost"
#
#
#config :numerino, Numerino.Repo,
#  adapter: Sqlite.Ecto,
#  database: "Numerino.sqlite3"
#
#config :logger,
#  handle_sasl_reports: true


# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for third-
# party users, it should be done in your mix.exs file.

# Sample configuration:
#
#     config :logger, :console,
#       level: :info,
#       format: "$date $time [$level] $metadata$message\n",
#       metadata: [:user_id]

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
#     import_config "#{Mix.env}.exs"
