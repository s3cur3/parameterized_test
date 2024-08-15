NimbleCSV.define(ParameterizedTest.TsvParser, separator: "\t", escape: "\"")
NimbleCSV.define(ParameterizedTest.CsvParser, separator: ",", escape: "\"")

defmodule ParameterizedTest do
  @moduledoc ~S"""
  A utility for defining eminently readable parameterized (or example-based) tests.

  Parameterized tests look like this:

      param_test "grants free shipping based on the marketing site's stated policy",
                 \"\"\"
                 | spending_by_category          | coupon      | ships_free? | description      |
                 |-------------------------------|-------------|-------------|------------------|
                 | %{shoes: 19_99, pants: 29_99} |             | false       | Spent too little |
                 | %{shoes: 59_99, pants: 49_99} |             | true        | Spent $100+      |
                 | %{socks: 10_99}               |             | true        | Socks ship free  |
                 | %{pants: 1_99}                | "FREE_SHIP" | true        | Correct coupon   |
                 \"\"\",
                 %{
                   spending_by_category: spending_by_category,
                   coupon: coupon,
                   ships_free?: ships_free?
                 } do
        shipping_cost = ShippingCalculator.calculate_shipping(spending_by_category, coupon)
        free_shipping? = shipping_cost == 0
        assert free_shipping? == ships_free?
      end

  Alternatively, if you don't like the Markdown table format, you can supply a
  hand-rolled list of parameters to the `param_test` macro, like this:

      param_test "shipping policy matches the web site",
                  [
                    # Items in the parameters list can be either maps...
                    %{spending_by_category: %{pants: 29_99}, coupon: "FREE_SHIP"},
                    # ...or keyword lists
                    [spending_by_category: %{shoes: 19_99, pants: 29_99}, coupon: nil]
                  ],
                  %{spending_by_category: spending_by_category, coupon: coupon} do
        ...
      end

  Just make sure that each item in the parameters list has the same keys.

  The final option is to pass a path to a *file* that contains your test parameters (we currently support `.md`/`.markdown`, `.csv`, and `.tsv` files), like this:

  ```elixir
  param_test "pull test parameters from a file",
              "test/fixtures/params.md",
              %{
                spending_by_category: spending_by_category,
                coupon: coupon,
                gets_free_shipping?: gets_free_shipping?
              } do
    ...
  end
  ```

  ## Why parameterized testing?

  Parameterized testing reduces toil associated with writing tests that cover
  a wide variety of different example cases. It also localizes the test logic
  into a single place, so that at a glance you can see how a number of
  different factors affect the behavior of the system under test.

  As a bonus, a table of examples (with their expected results) often
  matches how the business communicates the requirements of a system,
  both internally and to customers—for instance, in a table describing
  shipping costs based on how much a customer spends, where they're
  located, whether they've bought a promotional product, etc. This means
  parameterized tests can often be initially created by pulling directly from
  a requirements document that your product folks provide, and the
  product folks can later read the tests (or at least the parameters table)
  if they want to verify the behavior of the system.

  See the README for more information.
  """
  alias ParameterizedTest.Parser

  @doc """
  Defines tests that use your parameters or example data.

  Use it like:

      param_test "works as expected", your_parameters, %{value: from_context, expected_result: expected_result} do
        assert MyModule.process(from_context) == expected_result
      end
  """
  defmacro param_test(test_name, examples, context_ast \\ %{}, blocks) do
    context = Macro.Env.location(__ENV__)

    escaped_examples =
      case examples do
        str when is_binary(str) ->
          file_extension =
            str
            |> Path.extname()
            |> String.downcase()

          case file_extension do
            ext when ext in [".md", ".markdown", ".csv"] ->
              str
              |> Parser.parse_file_path_examples(context)
              |> Macro.escape()

            _ ->
              str
              |> Parser.parse_examples(context)
              |> Macro.escape()
          end

        list when is_list(list) ->
          list
          |> Parser.parse_examples(context)
          |> Macro.escape()

        already_escaped when is_tuple(already_escaped) ->
          already_escaped
      end

    quote location: :keep do
      for {example, index} <- Enum.with_index(unquote(escaped_examples)) do
        for {key, val} <- example do
          @tag [{key, val}]
        end

        custom_description =
          example[:test_desc] || example[:test_description] || example[:description] || example[:Description]

        un_truncated_name =
          case custom_description do
            nil -> "#{unquote(test_name)} (#{inspect(example)})"
            test_name -> "#{unquote(test_name)} - #{test_name}"
          end

        full_test_name =
          cond do
            String.length(un_truncated_name) <= 212 -> un_truncated_name
            is_nil(custom_description) -> "#{unquote(test_name)} row #{index}"
            true -> String.slice(un_truncated_name, 0, 212)
          end

        @tag param_test: true
        test "#{full_test_name}", unquote(context_ast) do
          unquote(blocks)
        end
      end
    end
  end

end
