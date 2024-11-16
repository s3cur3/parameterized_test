defmodule ParameterizedTest.SigilTest do
  use ExUnit.Case, async: true

  import ParameterizedTest
  import ParameterizedTest.Sigil, only: :sigils

  test "basic examples" do
    assert ~PARAMS"""
             | plan      | user_permission | can_invite?     |
             | :free     | :admin          | true            |
             | :free     | :editor         | "maybe"         |
             | :free     | :view_only      | false           |
             | :standard | :admin          | true            |
             | :standard | :editor         | "tuesdays only" |
             | :standard | :view_only      | false           |
           """ == [
             [plan: :free, user_permission: :admin, can_invite?: true],
             [plan: :free, user_permission: :editor, can_invite?: "maybe"],
             [plan: :free, user_permission: :view_only, can_invite?: false],
             [plan: :standard, user_permission: :admin, can_invite?: true],
             [plan: :standard, user_permission: :editor, can_invite?: "tuesdays only"],
             [plan: :standard, user_permission: :view_only, can_invite?: false]
           ]
  end

  test "discards headers" do
    assert ~PARAMS"""
             | plan      | user_permission | can_invite?     |
             |-----------|-----------------|-----------------|
             | :free     | :admin          | true            |
             | :free     | :editor         | "maybe"         |
           """ == [
             [plan: :free, user_permission: :admin, can_invite?: true],
             [plan: :free, user_permission: :editor, can_invite?: "maybe"]
           ]
  end

  test "allows any expression" do
    assert ~PARAMS"""
             | string               | integer    | keyword_list            |
             | String.upcase("foo") | div(17, 4) | [foo: :bar, baz: :bang] |
           """ == [
             [string: "FOO", integer: 4, keyword_list: [foo: :bar, baz: :bang]]
           ]
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
