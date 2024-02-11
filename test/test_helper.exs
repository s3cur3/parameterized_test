excluded_tags = [:integration, :local_integration, :todo]
ExUnit.start(exclude: excluded_tags, max_cases: System.schedulers_online() * 2)
