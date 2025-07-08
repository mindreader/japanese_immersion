ExUnit.start()
# I only want modules here that could cause side effects if used errantly.
# all other copies should be made in the test file itself.
Mimic.copy(Japanese.Corpus.StorageLayer)
Mimic.copy(Anthropix)
# Ecto.Adapters.SQL.Sandbox.mode(Japanese.Repo, :manual)
