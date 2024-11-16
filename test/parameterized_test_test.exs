defmodule ParameterizedTestTest do
  use ExUnit.Case, async: true
  use Wallaby.Feature

  import ParameterizedTest

  doctest ParameterizedTest, import: true

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
    param_test "matches stated policy on the marketing site",
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

    param_test "ignores commented lines",
               """
               | spending_by_category          | coupon      | gets_free_shipping? |
               |-------------------------------|-------------|---------------------|
               # Temporarily disable
               #| %{shoes: 19_99, pants: 29_99} |             | false               |
               | %{shoes: 59_99, pants: 49_99} |             | true                |
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

    param_test "supports obsidian-flavored markdown table separator rows",
               """
               | spending_by_category          | coupon      | gets_free_shipping? |
               | ----------------------------- | ----------- | ------------------- |
               | %{shoes: 59_99, pants: 49_99} |             | true                |
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

    param_test "supports Markdown files as input",
               "test/fixtures/params.md",
               %{
                 spending_by_category: spending_by_category,
                 coupon: coupon,
                 gets_free_shipping?: gets_free_shipping?
               } do
      shipping_cost = ExampleShippingCalculator.calculate_shipping(spending_by_category, coupon)
      free_shipping? = shipping_cost == 0
      assert free_shipping? == gets_free_shipping?
    end

    param_test "supports CSV files as input",
               "test/fixtures/params.csv",
               %{
                 coupon: coupon,
                 gets_free_shipping?: gets_free_shipping?
               } do
      assert (coupon == "FREE_SHIP" and gets_free_shipping?) or (is_nil(coupon) and not gets_free_shipping?)
    end

    param_test "supports TSV files as input",
               "test/fixtures/params.tsv",
               %{
                 coupon: coupon,
                 gets_free_shipping?: gets_free_shipping?
               } do
      assert (coupon == "FREE_SHIP" and gets_free_shipping?) or (is_nil(coupon) and not gets_free_shipping?)
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

    param_test "and allows them to be modified",
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
    param_test "truncates extremely long contexts to avoid overflowing the atom length limit",
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
               "test with a very, very, very, very, very, very, very, very, very long `describe` title truncates extremely long contexts to avoid overflowing the atom length limit row 0"
    end
  end

  param_test "interprets otherwise unparseable values as strings",
             """
             |  value  | unquoted string key          |
             |---------|------------------------------|
             |    1    | foo, bar & baz               |
             |  2 3 4  |                              |
             |  5      | Won't error out              |
             |  6      | a !@#$%^&*():"_;',./][}{<> z |
             |  7      |  %{shoes: 19_99,  |
             """,
             %{value: value, "unquoted string key": unquoted} do
    case value do
      1 ->
        assert unquoted == "foo, bar & baz"

      "2 3 4" ->
        assert is_nil(unquoted)

      5 ->
        assert unquoted == "Won't error out"

      6 ->
        assert unquoted == "a !@#$%^&*():\"_;',./][}{<> z"

      7 ->
        assert unquoted == "%{shoes: 19_99,"
    end
  end

  describe "user-provided description" do
    param_test "is supported",
               """
               | value | test_description |
               | 1     | "Lorem ipsum"    |
               | 2     | "Dolar sit amet" |
               | 3     |                  |
               """,
               %{value: value, test: ex_unit_test_name} do
      case value do
        1 ->
          assert ex_unit_test_name == :"test user-provided description is supported - Lorem ipsum"

        2 ->
          assert ex_unit_test_name == :"test user-provided description is supported - Dolar sit amet"

        3 ->
          assert ex_unit_test_name in [
                   :"test user-provided description is supported ([value: 3, test_description: nil])",
                   :"test user-provided description is supported ([test_description: nil, value: 3])"
                 ]
      end
    end

    param_test "is supported as test_desc",
               """
               | value | test_desc        |
               | 1     | "Lorem ipsum"    |
               | 2     | "Dolar sit amet" |
               | 3     |                  |
               """,
               %{value: value, test: ex_unit_test_name} do
      case value do
        1 ->
          assert ex_unit_test_name == :"test user-provided description is supported as test_desc - Lorem ipsum"

        2 ->
          assert ex_unit_test_name == :"test user-provided description is supported as test_desc - Dolar sit amet"

        3 ->
          assert ex_unit_test_name in [
                   :"test user-provided description is supported as test_desc ([value: 3, test_desc: nil])",
                   :"test user-provided description is supported as test_desc ([test_desc: nil, value: 3])"
                 ]
      end
    end

    param_test "is supported as description",
               """
               | value | description   |
               | 1     | "Lorem ipsum" |
               """,
               %{test: ex_unit_test_name} do
      assert ex_unit_test_name == :"test user-provided description is supported as description - Lorem ipsum"
    end

    param_test "is supported as Description",
               """
               | value | Description   |
               | 1     | "Lorem ipsum" |
               """,
               %{test: ex_unit_test_name} do
      assert ex_unit_test_name == :"test user-provided description is supported as Description - Lorem ipsum"
    end

    param_test "truncates long descriptions",
               """
               | value | Description   |
               | 1     | "This is an extremely long description which goes over the 255 character limit for atom length, blah blah blah blah blah blah blah blah blah blah blah blah blah blah blah blah blah blah blah blah blah blah blah blah blah blah blah blah blah blah" |
               """,
               %{test: ex_unit_test_name} do
      assert ex_unit_test_name ==
               :"test user-provided description truncates long descriptions - This is an extremely long description which goes over the 255 character limit for atom length, blah blah blah blah blah blah blah blah blah blah blah blah blah blah blah blah blah bl"
    end

    param_test "doesn't require quotes",
               """
               | value | description   |
               | 1     | Lorem ipsum   |
               """,
               %{test: ex_unit_test_name} do
      assert ex_unit_test_name ==
               :"test user-provided description doesn't require quotes - Lorem ipsum"
    end
  end

  @module_examples ParameterizedTest.Parser.parse_examples("""
                   | int_1 | int_2 |
                   | 99    | 100   |
                   """)

  param_test "accepts pre-parsed values from ~x sigil",
             @module_examples,
             %{int_1: int_1, int_2: int_2} do
    assert int_1 == 99
    assert int_2 == 100
  end

  param_test "accepts a list of maps or keyword lists",
             [
               [int_1: 99, int_2: 100],
               %{int_1: 101, int_2: 102}
             ],
             %{int_1: int_1, int_2: int_2} do
    assert int_1 + 1 == int_2
    assert int_1 in [99, 101]
    assert int_2 in [100, 102]
  end

  test "fails to compile Markdown rows with too few columns" do
    assert_raise RuntimeError, fn ->
      defmodule FailToEvaluateBadMarkdownTest do
        use ExUnit.Case, async: true

        import ParameterizedTest

        param_test "test with invalid markdown",
                   """
                   | spending_by_category          | coupon      | gets_free_shipping? |
                   |
                   """,
                   %{gets_free_shipping?: gets_free_shipping?} do
          assert gets_free_shipping?
        end
      end
    end
  end

  test "fails to compile when the keys in a handrolled list don't all match" do
    assert_raise RuntimeError, fn ->
      defmodule FailToEvaluateMismatchedKeys do
        @moduledoc false
        use ExUnit.Case, async: true

        import ParameterizedTest

        param_test "mismatched keys",
                   [
                     [int_1: 99, int_2: 100],
                     %{int_1: 101}
                   ],
                   %{int_1: int_1, int_2: int_2} do
          assert int_1 + 1 == int_2
          assert int_1 in [99, 101]
          assert int_2 in [100, 102]
        end
      end
    end
  end

  param_feature "supports Wallaby tests",
                """
                | text     | url                  |
                |----------|----------------------|
                | "GitHub" | "https://github.com" |
                | "Google" | "https://google.com" |
                """,
                %{session: session, text: text, url: url} do
    session
    |> visit(url)
    |> assert_has(Wallaby.Query.text(text, minimum: 1))
  end
end
