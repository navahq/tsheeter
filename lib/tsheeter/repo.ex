defmodule Tsheeter.Repo do
  use Ecto.Repo,
    otp_app: :tsheeter,
    adapter: Ecto.Adapters.Postgres
end
