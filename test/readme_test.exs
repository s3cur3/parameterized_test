defmodule ReadmeTest do
  use ExUnit.Case, async: true

  import ParameterizedTest

  doctest ParameterizedTest, import: true

  defmodule Posts do
    @moduledoc false
    def can_view?(user) do
      user[:permissions] in [:admin, :editor, :viewer]
    end

    def can_edit?(user) do
      user[:permissions] in [:admin, :editor]
    end
  end

  setup context do
    # context.permissions gets set by the param_test below
    permissions = Map.get(context, :permissions, nil)
    %{user: %{permissions: permissions}}
  end

  param_test "users with at least editor permissions can edit posts",
             """
             | permissions | can_edit? | description                     |
             |-------------|-----------|---------------------------------|
             | :admin      | true      | Admins have max permissions     |
             | :editor     | true      | Editors can edit (of course!)   |
             | :viewer     | false     | Viewers are read-only           |
             | nil         | false     | Anonymous viewers are read-only |
             """,
             %{user: user, permissions: permissions, can_edit?: can_edit?} do
    assert Posts.can_edit?(user) == can_edit?, "#{permissions} permissions should grant edit rights"
  end

  for {permissions, can_edit?, description} <- [
        {:admin, true, "Admins have max permissions"},
        {:editor, true, "Editors can edit (of course!)"},
        {:viewer, false, "Viewers are read-only"},
        {nil, false, "Anonymous viewers are read-only"}
      ] do
    @permissions permissions
    @can_edit? can_edit?
    @description description

    @tag permissions: @permissions
    @tag can_edit?: @can_edit?
    @tag description: @description
    test "users with at least editor permissions can edit posts — #{@description}", %{user: user} do
      assert Posts.can_edit?(user) == @can_edit?
    end
  end

  defmodule ShippingCalculator do
    @moduledoc false
    def calculate(total_cents_spent, coupon) when is_number(total_cents_spent) do
      if total_cents_spent >= 99 * 100 or coupon == "FREE_SHIP" do
        0
      else
        5_00
      end
    end

    def calculate(spending_by_category, coupon) when is_map(spending_by_category) do
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

  param_test "grants free shipping based on the marketing site's stated policy",
             """
             | spending_by_category          | coupon      | ships_free? | description      |
             |-------------------------------|-------------|-------------|------------------|
             | %{shoes: 19_99, pants: 29_99} |             | false       | Spent too little |
             | %{shoes: 59_99, pants: 49_99} |             | true        | Spent over $100  |
             | %{socks: 10_99}               |             | true        | Socks ship free  |
             | %{pants: 1_99}                | "FREE_SHIP" | true        | Correct coupon   |
             | %{pants: 1_99}                | "FOO"       | false       | Incorrect coupon |
             """,
             %{
               spending_by_category: spending_by_category,
               coupon: coupon,
               ships_free?: ships_free?
             } do
    shipping_cost = ShippingCalculator.calculate(spending_by_category, coupon)

    if ships_free? do
      assert shipping_cost == 0
    else
      assert shipping_cost > 0
    end
  end

  param_test "grants free shipping for spending $99 or more, or with coupon FREE_SHIP",
             """
             | total_cents | coupon      | free? | description                 |
             | ----------- | ----------- | ----- | --------------------------- |
             | 98_99       |             | false | Spent too little            |
             | 99_00       |             | true  | Min for free shipping       |
             | 99_01       |             | true  | Spent more than the minimum |
             | 1_00        | "FREE_SHIP" | true  | Had the right coupon        |
             | 1_00        | "FOO"       | false | Unrecognized coupon         |
             """,
             %{total_cents: total_cents, coupon: coupon, free?: gets_free_shipping?} do
    shipping_cost = ShippingCalculator.calculate(total_cents, coupon)
    free_shipping? = shipping_cost == 0
    assert free_shipping? == gets_free_shipping?
  end
end
