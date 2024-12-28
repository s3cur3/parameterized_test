run_wallaby_tests? = Enum.member?(ExUnit.configuration()[:include], :feature)

if run_wallaby_tests? do
  {:ok, _} = Application.ensure_all_started(:wallaby)
end

excluded_tags = [:integration, :local_integration, :feature, :todo, :failure_with_backtrace]
ExUnit.start(exclude: excluded_tags, max_cases: System.schedulers_online() * 2)
