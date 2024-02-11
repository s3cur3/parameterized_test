defmodule ExampleTestTest do
  use ExUnit.Case, async: true

  import ExampleTest

  doctest ExampleTest, import: true

  test "basic examples" do
    assert ~EXAMPLES"""
             | plan      | user_permission | can_invite?     |
             | :free     | :admin          | true            |
             | :free     | :editor         | "maybe"         |
             | :free     | :view_only      | false           |
             | :standard | :admin          | true            |
             | :standard | :editor         | "tuesdays only" |
             | :standard | :view_only      | false           |
           """ == [
             %{plan: :free, user_permission: :admin, can_invite?: true},
             %{plan: :free, user_permission: :editor, can_invite?: "maybe"},
             %{plan: :free, user_permission: :view_only, can_invite?: false},
             %{plan: :standard, user_permission: :admin, can_invite?: true},
             %{plan: :standard, user_permission: :editor, can_invite?: "tuesdays only"},
             %{plan: :standard, user_permission: :view_only, can_invite?: false}
           ]
  end

  test "discards headers" do
    assert ~EXAMPLES"""
             | plan      | user_permission | can_invite?     |
             |-----------|-----------------|-----------------|
             | :free     | :admin          | true            |
             | :free     | :editor         | "maybe"         |
           """ == [
             %{plan: :free, user_permission: :admin, can_invite?: true},
             %{plan: :free, user_permission: :editor, can_invite?: "maybe"}
           ]
  end

  test "allows any expression" do
    assert ~EXAMPLES"""
             | string               | integer    | keyword_list            |
             | String.upcase("foo") | div(17, 4) | [foo: :bar, baz: :bang] |
           """ == [
             %{string: "FOO", integer: 4, keyword_list: [foo: :bar, baz: :bang]}
           ]
  end

  defmodule ExampleShippingCalculator do
    @moduledoc false
    def calculate_shipping(spending_by_category, coupon) do
      bought_socks? = Map.get(spending_by_category, :socks, 0) > 0

      total_spent =
        spending_by_category
        |> Map.values()
        |> Enum.sum()

      if bought_socks? or total_spent > 10_000 or coupon == "FREE_SHIP" do
        0
      else
        5_00
      end
    end
  end

  describe "shipping policy" do
    example_test "matches stated policy on the marketing site",
                 """
                 | spending_by_category          | coupon      | gets_free_shipping? |
                 |-------------------------------|-------------|---------------------|
                 | %{shoes: 19_99, pants: 29_99} |             | false               |
                 | %{shoes: 59_99, pants: 49_99} |             | true                |
                 | %{socks: 10_99}               |             | true                |
                 | %{shoes: 19_99}               | "FREE_SHIP" | true                |
                 """,
                 %{
                   spending_by_category: spending_by_category,
                   coupon: coupon,
                   gets_free_shipping?: gets_free_shipping?
                 } do
      shipping_cost = ExampleShippingCalculator.calculate_shipping(spending_by_category, coupon)
      free_shipping? = shipping_cost == 0
      assert free_shipping? == gets_free_shipping?
    end
  end

  defmodule ExampleAccounts do
    @moduledoc false
    def create_user(%{permissions: permissions}) do
      %{permissions: permissions}
    end
  end

  describe "makes values available to `setup`" do
    setup %{int_1: int_1, int_2: int_2} do
      %{int_1: int_1 * 2, int_2: int_2 * 2}
    end

    example_test "and allows them to be modified",
                 """
                 | int_1 | int_2 |
                 | 2     | 4     |
                 """,
                 %{int_1: int_1, int_2: int_2} do
      assert int_1 == 4
      assert int_2 == 8
    end
  end

  describe "with a very, very, very, very, very, very, very, very, very long `describe` title" do
    example_test "truncates extremely long contexts to avoid overflowing the atom length limit",
                 """
                 | variable_1 | variable_2 |
                 | "foo"      | "012345678911234567892123456789312345678941234567895123456789612345678971234567898123456789912345678901234567891123456789212345678931234567894123456789512345678961234567897123456789812345678991234567890123456789112345678921234567893123456789412345678951234567896123456789712345678981234567899123456789" |
                 """,
                 %{variable_1: variable_1, variable_2: variable_2, test: test} do
      assert variable_1 == "foo"

      assert variable_2 ==
               "012345678911234567892123456789312345678941234567895123456789612345678971234567898123456789912345678901234567891123456789212345678931234567894123456789512345678961234567897123456789812345678991234567890123456789112345678921234567893123456789412345678951234567896123456789712345678981234567899123456789"

      assert String.length(variable_2) == 300

      test_name = Atom.to_string(test)
      assert String.length(test_name) <= 255

      assert test_name ==
               "test with a very, very, very, very, very, very, very, very, very long `describe` title truncates extremely long contexts to avoid overflowing the atom length limit (%{variable_1: \"foo\", variable_2: \"012345678911234567892123456789312345678941)"
    end
  end
end
