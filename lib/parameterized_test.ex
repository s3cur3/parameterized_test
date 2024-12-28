NimbleCSV.define(ParameterizedTest.TsvParser, separator: "\t", escape: "\"")
NimbleCSV.define(ParameterizedTest.CsvParser, separator: ",", escape: "\"")

defmodule ParameterizedTest do
  @moduledoc """
  A utility for defining eminently readable parameterized (or example-based) tests.

  Parameterized tests look like this:

      param_test "grants free shipping based on the marketing site's stated policy",
                 \"\"\"
                 | spending_by_category          | coupon      | ships_free? | description      |
                 |-------------------------------|-------------|-------------|------------------|
                 | %{shoes: 19_99, pants: 29_99} |             | false       | Spent too little |
                 | %{shoes: 59_99, pants: 49_99} |             | true        | Spent $100+      |
                 | %{socks: 10_99}               |             | true        | Socks ship free  |
                 | %{pants: 1_99}                | \"FREE_SHIP\" | true        | Correct coupon   |
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
  require ParameterizedTest.Backtrace

  @doc """
  Defines tests that use your parameters or example data.

  Use it like:

      param_test \"grants free shipping for spending $99+ or with coupon FREE_SHIP\",
                 \"\"\"
                 | total_cents | ships_free? | description                 |
                 | ----------- | ----------- | --------------------------- |
                 | 98_99       | false       | Spent too little            |
                 | 99_00       | true        | Min for free shipping       |
                 | 99_01       | true        | Spent more than the minimum |
                 \"\"\",
                 %{total_cents: total_cents, ships_free?: ships_free?} do
        shipping_cost = ShippingCalculator.calculate(total_cents)

        if ships_free? do
          assert shipping_cost == 0
        else
          assert shipping_cost > 0
        end
      end

  """
  defmacro param_test(test_name, examples, context_ast \\ quote(do: %{}), blocks) do
    quote location: :keep do
      context = Macro.Env.location(__ENV__)
      escaped_examples = ParameterizedTest.Macros.escape_examples(unquote(examples), context)

      block_tags = Module.get_attribute(__MODULE__, :tag)

      for {{example, context}, index} <- Enum.with_index(escaped_examples) do
        for {key, val} <- example do
          @tag [{key, val}]
        end

        unquoted_test_name = unquote(test_name)
        full_test_name = ParameterizedTest.Parser.full_test_name(unquoted_test_name, example, index, 212)

        # "Forward" tags defined on the param_test macro itself
        for [{key, val} | _] <- block_tags do
          @tag [{key, val}]
        end

        @param_test_context context

        @tag param_test: true
        test "#{full_test_name}", unquote(context_ast) do
          try do
            unquote(blocks)
          rescue
            e in ExUnit.AssertionError ->
              ParameterizedTest.Backtrace.add_test_context(e, __STACKTRACE__, @param_test_context)
          end
        end
      end
    end
  end

  if Code.ensure_loaded?(Wallaby) do
    @doc """
    Defines Wallaby feature tests that use your parameters or example data.

    This is to the Wallaby `feature` macro as `param_test` is to `test`.

    Use it like this:

        param_feature \"supports Wallaby tests\",
                      \"\"\"
                      | text     | url                  |
                      |----------|----------------------|
                      | \"GitHub\" | \"https://github.com\" |
                      | \"Google\" | \"https://google.com\" |
                      \"\"\",
                      %{session: session, text: text, url: url} do
          session
          |> visit(url)
          |> assert_has(Wallaby.Query.text(text, minimum: 1))
        end
    """
    defmacro param_feature(test_name, examples, context_ast \\ quote(do: %{}), blocks) do
      quote location: :keep do
        context = Macro.Env.location(__ENV__)
        escaped_examples = ParameterizedTest.Macros.escape_examples(unquote(examples), context)

        block_tags = Module.get_attribute(__MODULE__, :tag)

        for {{example, context}, index} <- Enum.with_index(escaped_examples) do
          for {key, val} <- example do
            @tag [{key, val}]
          end

          unquoted_test_name = unquote(test_name)
          @full_test_name ParameterizedTest.Parser.full_test_name(unquoted_test_name, example, index, 212)

          # "Forward" tags defined on the param_test macro itself
          for [{key, val} | _] <- block_tags do
            @tag [{key, val}]
          end

          @param_test_context context

          @tag param_test: true
          feature "#{@full_test_name}", unquote(context_ast) do
            try do
              unquote(blocks)
            rescue
              e in ExUnit.AssertionError ->
                ParameterizedTest.Backtrace.add_test_context(e, __STACKTRACE__, @param_test_context)
            end
          end
        end
      end
    end
  end
end
