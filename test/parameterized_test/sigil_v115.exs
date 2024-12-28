defmodule ParameterizedTest.SigilTest do
  use ExUnit.Case, async: true

  import ParameterizedTest
  import ParameterizedTest.Sigil, only: :sigils

  test "basic examples" do
    parsed = ~PARAMS"""
      | plan      | user_permission | can_invite?     |
      | :free     | :admin          | true            |
      | :free     | :editor         | "maybe"         |
      | :free     | :view_only      | false           |
      | :standard | :admin          | true            |
      | :standard | :editor         | "tuesdays only" |
      | :standard | :view_only      | false           |
    """

    assert Enum.map(parsed, &elem(&1, 0)) == [
             [plan: :free, user_permission: :admin, can_invite?: true],
             [plan: :free, user_permission: :editor, can_invite?: "maybe"],
             [plan: :free, user_permission: :view_only, can_invite?: false],
             [plan: :standard, user_permission: :admin, can_invite?: true],
             [plan: :standard, user_permission: :editor, can_invite?: "tuesdays only"],
             [plan: :standard, user_permission: :view_only, can_invite?: false]
           ]

    contexts = Enum.map(parsed, &elem(&1, 1))
    [first_context | _] = contexts
    assert first_context[:min_line] == 9

    assert Enum.map(contexts, & &1[:min_line]) ==
             Enum.to_list(first_context[:min_line]..(first_context[:min_line] + length(parsed) - 1))

    assert Enum.all?(contexts, &(&1[:file] == __ENV__.file))
  end

  test "discards headers" do
    parsed = ~PARAMS"""
      | plan      | user_permission | can_invite?     |
      |-----------|-----------------|-----------------|
      | :free     | :admin          | true            |
      | :free     | :editor         | "maybe"         |
    """

    assert [
             {[plan: :free, user_permission: :admin, can_invite?: true], _},
             {[plan: :free, user_permission: :editor, can_invite?: "maybe"], _}
           ] = parsed
  end

  test "allows any expression" do
    assert [{[string: "FOO", integer: 4, keyword_list: [foo: :bar, baz: :bang]], context}] = ~PARAMS"""
             | string               | integer    | keyword_list            |
             | String.upcase("foo") | div(17, 4) | [foo: :bar, baz: :bang] |
           """

    macro_line = __ENV__.line - 5

    assert Enum.sort(context) ==
             Enum.sort(
               file: __ENV__.file,
               line: macro_line,
               min_line: macro_line + 1,
               raw: "| String.upcase(\"foo\") | div(17, 4) | [foo: :bar, baz: :bang] |"
             )
  end

  param_test "param_test accepts pre-parsed values from ~x sigil",
             ~PARAMS"""
             | int_1 | int_2 |
             | 2     | 4     |
             """,
             %{int_1: int_1, int_2: int_2} do
    assert int_1 == 2
    assert int_2 == 4
  end
end
