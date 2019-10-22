# File extracted from master Ecto, unmodified
Code.require_file "test_adapter.exs", __DIR__
# File extraced from master Ecto, modified with prepare_query, otp_app, and split file
Code.require_file "test_repo.exs", __DIR__

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Tenancy.Repo, :manual)
