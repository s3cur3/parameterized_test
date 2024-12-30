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
    first_test_line = __ENV__.line

    if should_fail? do
      context = [file: __ENV__.file, min_line: first_test_line - 7, raw: "| true         |"]

      try do
        assert not should_fail?
      catch
        category, reason ->
          try do
            ParameterizedTest.Backtrace.add_test_context({category, reason}, __STACKTRACE__, context)
          rescue
            ExUnit.AssertionError ->
              assert [failing_line, parameter_line | _] = __STACKTRACE__

              assert {__MODULE__, f1, 1, context1} = failing_line
              assert f1 == :"test gives the failing parameter row when a test fails ([should_fail?: true])"
              assert context1[:line] == first_test_line + 6

              assert {__MODULE__, f2, 0, context2} = parameter_line
              # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
              assert f2 == String.to_atom(context[:raw])
              assert context2[:line] == first_test_line - 3
          end
      end
    else
      assert not should_fail?
    end
  end

  @tag failure_with_backtrace: true
  param_test "points to line #{__ENV__.line + 4} when a test fails",
             """
             | should_fail? | description |
             | false        | "Works"     |
             | true         | "Breaks"    |
             """,
             %{should_fail?: should_fail?} do
    assert not should_fail?
  end

  @tag failure_with_backtrace: true
  param_test "with added comments, should point to line #{__ENV__.line + 7}",
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
  param_test "with a description, should point to line #{__ENV__.line + 4}",
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
    "with parens, should point to line #{__ENV__.line + 3}",
    """
    | variable_1 | variable_2 |
    | "foo"      | "bar"      |
    """,
    %{variable_1: variable_1, variable_2: variable_2}
  ) do
    assert variable_1 == "foo"
    assert variable_2 != "bar"
  end

  @tag skip: true
  @tag failure_with_backtrace: true
  param_feature(
    "feature with parens should point to line #{__ENV__.line + 4}",
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
  param_test "hand-rolled params shouldn't give attribution", [[variable_1: "foo", variable_2: "bar"]], %{
    variable_1: variable_1,
    variable_2: variable_2
  } do
    assert variable_1 == "foo"
    assert variable_2 != "bar"
  end

  @tag skip: true
  @tag failure_with_backtrace: true
  param_feature "hand-rolled params shouldn't give attribution", [[variable_1: "foo", variable_2: "bar"]], %{
    variable_1: variable_1,
    variable_2: variable_2
  } do
    assert variable_1 == "foo"
    assert variable_2 != "bar"
  end

  @tag failure_with_backtrace: true
  param_test "attributes Markdown error to test/fixtures/params.md line 6",
             "test/fixtures/params.md",
             %{coupon: coupon} do
    assert is_nil(coupon)
  end

  @tag failure_with_backtrace: true
  param_test "attributes CSV error to test/fixtures/params.csv line 2", "test/fixtures/params.csv", %{
    gets_free_shipping?: gets_free_shipping?
  } do
    assert gets_free_shipping?
  end

  @tag failure_with_backtrace: true
  param_test "attributes TSV error to test/fixtures/params.tsv line 3", "test/fixtures/params.tsv", %{
    gets_free_shipping?: gets_free_shipping?
  } do
    assert not gets_free_shipping?
  end

  @tag failure_with_backtrace: true
  param_test "handles other exceptions, attribute to line #{__ENV__.line + 4}",
             """
             | should_fail? |
             | false        |
             | true         |
             """,
             %{should_fail?: should_fail?} do
    if should_fail? do
      raise "test failed"
    else
      assert 1 == 1
    end
  end

  @tag failure_with_backtrace: true
  param_test "handles code errors, attribute to line #{__ENV__.line + 4}",
             """
             | should_fail? |
             | false        |
             | true         |
             """,
             %{should_fail?: should_fail?} do
    if should_fail? do
      assert Code.eval_string("nil + 1") == 2
    else
      assert 1 == 1
    end
  end

  defmodule SlowGenServer do
    @moduledoc false
    @behaviour GenServer

    def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

    @impl GenServer
    def init(_), do: {:ok, []}

    def slow_call(pid) do
      GenServer.call(pid, :slow_call, 0)
    end

    @impl GenServer
    def handle_call(:slow_call, _from, state) do
      :timer.sleep(1000)
      {:reply, :ok, state}
    end
  end

  @tag failure_with_backtrace: true
  param_test "handles non-assertion errors too, attribute to line #{__ENV__.line + 4}",
             """
             | should_fail? |
             | false        |
             | true         |
             """,
             %{should_fail?: should_fail?} do
    if should_fail? do
      {:ok, pid} = SlowGenServer.start_link()
      SlowGenServer.slow_call(pid)
    end
  end

  @tag failure_with_backtrace: true
  param_feature "handles non-assertion errors in features, attribute to line #{__ENV__.line + 4}",
                """
                | should_fail? |
                | false        |
                | true         |
                """,
                %{should_fail?: should_fail?} do
    if should_fail? do
      {:ok, pid} = SlowGenServer.start_link()
      SlowGenServer.slow_call(pid)
    end
  end
end
