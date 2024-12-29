if Version.match?(System.version(), "< 1.15.0") do
  Code.require_file("lib/parameterized_test/sigil_v114.exs")
else
  Code.require_file("lib/parameterized_test/sigil_v115.exs")
end

# This module exists solely to force the sigil to be recompiled when
# the included file changes.
defmodule ParameterizedTest.SigilDependency do
  @moduledoc false
  if Version.match?(System.version(), "< 1.15.0") do
    @external_resource "lib/parameterized_test/sigil_v114.exs"
  else
    @external_resource "lib/parameterized_test/sigil_v115.exs"
  end
end
