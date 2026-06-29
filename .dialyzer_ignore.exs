# You can get the spec for these errors to ignore by running:
#     $ mix dialyzer --format short
# ...and then taking that "short" output and either reproducing it whole here or by
# pulling out the file and error atom.
#
# More info in the Dialyxir README:
# https://github.com/jeremyjh/dialyxir#elixir-term-format
[
  # Elixir 1.20 ignores `log: false` in Code.eval_string/3 calls, but earlier versions need it.
  {"lib/parameterized_test/parser.ex", :call}
]
