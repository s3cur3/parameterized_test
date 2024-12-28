defmodule ParameterizedTest.BacktraceTest do
  # Tyler notes: This module is *extremely* brittle, because the line numbers are hardcoded.
  # Pretty much any change to existing code will break a number of tests.
  # This is to be expected, and is kind of the price to pay for getting really
  # obviously correct behavior here.
  use ExUnit.Case, async: true

  import ParameterizedTest

  param_test "gives the failing parameter row when a test fails",
             """
             | should_fail? |
             | false        |
             | true         |
             """,
             %{should_fail?: should_fail?} do
    if should_fail? do
      context = [file: "test/parameterized_test/backtrace_test.exs", min_line: 12, raw: "| true         |"]

      try do
        assert not should_fail?
      rescue
        e in ExUnit.AssertionError ->
          try do
            ParameterizedTest.Backtrace.add_test_context(e, __STACKTRACE__, context)
          rescue
            ExUnit.AssertionError ->
              assert [failing_line, parameter_line | _] = __STACKTRACE__

              assert {__MODULE__, f1, 1, context1} = failing_line
              assert f1 == :"test gives the failing parameter row when a test fails ([should_fail?: true])"
              assert context1[:line] == 22

              assert {__MODULE__, f2, 0, context2} = parameter_line
              # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
              assert f2 == String.to_atom(context[:raw])
              assert context2[:line] == 15
          end
      end
    else
      assert not should_fail?
    end
  end

  describe "a describe block" do
    @tag failure_with_backtrace: true
    param_test "points to line 51 when a test fails",
               """
               | should_fail? | description |
               | false        | "Works"     |
               | true         | "Breaks"    |
               """,
               %{should_fail?: should_fail?} do
      assert not should_fail?
    end
  end

  @tag failure_with_backtrace: true
  param_test "with added comments, should point to line 66",
             # This is a comment to break the normal (inferrable) line number
             # Another line to screw it up!
             """
             | variable_1 | variable_2 |
             # Comment that should be skipped in the line count
             # Comment that should be skipped in the line count
             | "foo"      | "012345678911234567892123456789312345678941234567895123456789612345678971234567898123456789912345678901234567891123456789212345678931234567894123456789512345678961234567897123456789812345678991234567890123456789112345678921234567893123456789412345678951234567896123456789712345678981234567899123456789" |
             """,
             %{variable_1: variable_1, variable_2: variable_2} do
    assert variable_1 == "foo"
    assert variable_2 == "012345678911234567892123456"
  end

  @tag failure_with_backtrace: true
  param_test "with a description, should point to line 78",
             # This is a comment to break the normal (inferrable) line number
             """
             | variable_1 | variable_2 | description |
             | "foo"      | "bar"      | "should fail" |
             """,
             %{variable_1: variable_1, variable_2: variable_2} do
    assert variable_1 == "foo"
    assert variable_2 != "bar"
  end

  @tag failure_with_backtrace: true
  param_test(
    "with parens, should point to line 90",
    """
    | variable_1 | variable_2 |
    | "foo"      | "bar"      |
    """,
    %{variable_1: variable_1, variable_2: variable_2}
  ) do
    assert variable_1 == "foo"
    assert variable_2 != "bar"
  end

  @tag failure_with_backtrace: true
  param_feature(
    "feature with parens should point to line 104",
    """
    | variable_1 | variable_2 |

    | "foo"      | "bar"      |
    """,
    %{variable_1: variable_1, variable_2: variable_2}
  ) do
    assert variable_1 == "foo"
    assert variable_2 != "bar"
  end
end
