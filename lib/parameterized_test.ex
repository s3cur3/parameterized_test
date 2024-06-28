defmodule ParameterizedTest do
  @moduledoc ~S"""
  A utility for defining eminently readable example-based tests.

  Example tests look like this:

      param_test "grants free shipping based on the marketing site's stated policy",
                 \"\"\"
                 | spending_by_category          | coupon      | gets_free_shipping? |
                 | %{shoes: 19_99, pants: 29_99} |             | false               |
                 | %{shoes: 59_99, pants: 49_99} |             | true                |
                 | %{socks: 10_99}               |             | true                |
                 | %{pants: 1_99}                | "FREE_SHIP" | true                |
                 \"\"\",
                 %{
                   spending_by_category: spending_by_category,
                   coupon: coupon,
                   gets_free_shipping?: gets_free_shipping?
                 } do
        shipping_cost = ShippingCalculator.calculate_shipping(spending_by_category, coupon)
        free_shipping? = shipping_cost == 0
        assert free_shipping? == gets_free_shipping?
      end

  ## Why example testing?

  Example testing reduces toil associated with writing tests that cover
  a wide variety of different cases. It also localizes the test logic
  into a single place, so that at a glance you can see how a number of
  different factors affect the behavior of the system under test.

  As a bonus, a table of examples (with their expected results) often
  matches how the business communicates the requirements of a system,
  both internally and to customers—for instance, in a table describing
  shipping costs based on how much a customer spends, where they're
  located, whether they've bought a promotional product, etc. This means
  example tests can often be initially created by pulling directly from
  a requirements document that your product folks provided, and the
  product folks can later read the tests (or at least the examples table)
  if they want to verify the behavior of the system.
  """

  @doc """
  Defines tests that use your example data.

  Use it like:

      param_test "works as expected", examples, %{value: from_context, expected_result: expected_result} do
        assert something(from_context) == expected_result
      end
  """
  defmacro param_test(test_name, examples, context_ast \\ %{}, blocks) do
    context = Macro.Env.location(__ENV__)

    escaped_examples =
      case examples do
        str when is_binary(str) -> str |> parse_examples(context) |> Macro.escape()
        already_escaped when is_tuple(already_escaped) -> already_escaped
      end

    max_describe_length_to_fit_on_one_line = 82
    test_name_length = String.length(test_name)
    # Theoretically an atom can be 255 characters, but there's extra stuff appended to the test
    # name that eats up extra characters.
    max_context_length = 255 - test_name_length - max_describe_length_to_fit_on_one_line - 22

    quote location: :keep do
      for example <- unquote(escaped_examples) do
        for {key, val} <- example do
          @tag [{key, val}]
        end

        @tag param_test: true
        test "#{unquote(test_name)} (#{example |> inspect() |> String.slice(0..unquote(max_context_length))})",
             unquote(context_ast) do
          unquote(blocks)
        end
      end
    end
  end

  @typep context :: [{:line, integer} | {:file, String.t()}]

  @spec parse_examples(String.t(), context()) :: [map()]
  def parse_examples(table, context \\ []) do
    rows =
      table
      |> String.split("\n", trim: true)
      |> Enum.map(&String.trim/1)

    case rows do
      [header | rows] ->
        headers =
          header
          |> split_cells()
          |> Enum.map(&String.to_atom/1)

        rows
        |> Enum.reject(&separator_row?/1)
        |> Enum.map(fn row ->
          cells =
            row
            |> split_cells()
            |> Enum.map(fn cell ->
              try do
                case Code.eval_string(cell) do
                  {val, []} -> val
                  _ -> raise "Failed to evaluate example cell `#{cell}` in row `#{row}`"
                end
              rescue
                e ->
                  reraise "Failed to evaluate example cell `#{cell}` in row `#{row}`. #{inspect(e)}", __STACKTRACE__
              end
            end)

          if length(cells) != length(headers) do
            file_meta =
              case {context[:file], context[:line]} do
                {file, line} when is_binary(file) and is_integer(line) -> " (#{file}:#{line})"
                {nil, nil} -> ""
              end

            raise """
            The number of cells in each row must exactly match the
            number of headers on your example table.

            Problem row#{file_meta}:
            #{row}

            Expected headers:
            #{inspect(headers)}
            """
          end

          headers
          |> Enum.zip(cells)
          |> Map.new()
        end)
        |> Enum.reject(&(&1 == %{}))

      [] ->
        []
    end
  end

  defp split_cells(row) do
    row
    |> String.split("|", trim: true)
    |> Enum.map(&String.trim/1)
  end

  # A regex to match rows consisting of pipes separated by hyphens, like |------|-----|
  @separator_regex ~r/^\|(-+\|)+$/

  defp separator_row?(row) do
    Regex.match?(@separator_regex, row)
  end
end
