NimbleCSV.define(ParameterizedTest.TsvParser, separator: "\t", escape: "\"")
NimbleCSV.define(ParameterizedTest.CsvParser, separator: ",", escape: "\"")

defmodule ParameterizedTest do
  @moduledoc ~S"""
  A utility for defining eminently readable parameterized (or example-based) tests.

  Parameterized tests look like this:

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
              |> parse_file_path_examples(context)
              |> Macro.escape()

            _ ->
              str
              |> parse_examples(context)
              |> Macro.escape()
          end

        list when is_list(list) ->
          list
          |> parse_examples(context)
          |> Macro.escape()

        already_escaped when is_tuple(already_escaped) ->
          already_escaped
      end

    quote location: :keep do
      for {example, index} <- Enum.with_index(unquote(escaped_examples)) do
        for {key, val} <- example do
          @tag [{key, val}]
        end

        un_truncated_name = "#{unquote(test_name)} (#{inspect(example)})"

        full_test_name =
          if String.length(un_truncated_name) < 255 do
            un_truncated_name
          else
            "#{unquote(test_name)} row #{index}"
          end

        @tag param_test: true
        test "#{full_test_name}", unquote(context_ast) do
          unquote(blocks)
        end
      end
    end
  end

  @typep context :: [{:line, integer} | {:file, String.t()}]

  @spec parse_examples(String.t() | list, context()) :: [map()]
  def parse_examples(table, context \\ [])

  def parse_examples(table, context) when is_binary(table) do
    table
    |> String.split("\n", trim: true)
    |> Enum.map(&String.trim/1)
    |> parse_md_rows(context)
  end

  # This function head handles a list of already-parsed examples, like:
  # param_test "accepts a list of maps or keyword lists",
  #            [
  #              [int_1: 99, int_2: 100],
  #              %{int_1: 101, int_2: 102}
  #            ], %{int_1: int_1, int_2: int_2} do
  def parse_examples(table, context) when is_list(table) do
    {evaled_table, _, _} = Code.eval_quoted_with_env(table, [], __ENV__)

    case evaled_table do
      str when is_binary(str) -> parse_file_path_examples(str, context)
      list when is_list(list) -> parse_hand_rolled_table(list, context)
    end
  end

  defp parse_hand_rolled_table(evaled_table, context) do
    parsed_table = Enum.map(evaled_table, &Map.new/1)

    keys = MapSet.new(parsed_table, &Map.keys/1)

    if MapSet.size(keys) > 1 do
      raise """
      The keys in each row must be the same across all rows in your example table.

      Found differing key sets#{file_meta(context)}:
      #{for key_set <- Enum.sort(keys), do: inspect(key_set)}
      """
    end

    parsed_table
  end

  defp parse_file_path_examples(path, context) do
    file = File.read!(path)

    case path |> Path.extname() |> String.downcase() do
      md when md in [".md", ".markdown"] -> parse_examples(file, context)
      ".csv" -> parse_csv_file(file, context)
      ".tsv" -> parse_tsv_file(file, context)
      _ -> raise "Unsupported file extension for parameterized tests #{path} #{file_meta(context)}"
    end
  end

  defp parse_csv_file(file, context) do
    file
    |> ParameterizedTest.CsvParser.parse_string(skip_headers: false)
    |> parse_csv_rows(context)
  end

  defp parse_tsv_file(file, context) do
    file
    |> ParameterizedTest.TsvParser.parse_string()
    |> Enum.map(&String.trim/1)
    |> parse_csv_rows(context)
  end

  defp parse_md_rows(rows, context)
  defp parse_md_rows([], _context), do: []

  defp parse_md_rows([header | rows], context) do
    headers =
      header
      |> split_cells()
      |> Enum.map(&String.to_atom/1)

    rows
    |> Enum.reject(&separator_or_comment_row?/1)
    |> Enum.map(fn row ->
      cells =
        row
        |> split_cells()
        |> Enum.map(&eval_cell(&1, row, context))

      check_cell_count(cells, headers, row, context)

      headers
      |> Enum.zip(cells)
      |> Map.new()
    end)
    |> Enum.reject(&(&1 == %{}))
  end

  defp parse_csv_rows(rows, context)
  defp parse_csv_rows([], _context), do: []

  defp parse_csv_rows([header | rows], context) do
    headers = Enum.map(header, &String.to_atom/1)

    rows
    |> Enum.map(fn row ->
      cells = Enum.map(row, &eval_cell(&1, row, context))

      check_cell_count(cells, headers, row, context)

      headers
      |> Enum.zip(cells)
      |> Map.new()
    end)
    |> Enum.reject(&(&1 == %{}))
  end

  defp eval_cell(cell, row, _context) do
    case Code.eval_string(cell) do
      {val, []} -> val
      _ -> raise "Failed to evaluate example cell `#{cell}` in row `#{row}`}"
    end
  rescue
    e ->
      reraise "Failed to evaluate example cell `#{cell}` in row `#{row}`. #{inspect(e)}", __STACKTRACE__
  end

  defp check_cell_count(cells, headers, row, context) do
    if length(cells) != length(headers) do
      raise """
      The number of cells in each row must exactly match the
      number of headers on your example table.

      Problem row#{file_meta(context)}:
      #{row}

      Expected headers:
      #{inspect(headers)}
      """
    end
  end

  defp split_cells(row) do
    row
    |> String.split("|", trim: true)
    |> Enum.map(&String.trim/1)
  end

  # A regex to match rows consisting of pipes separated by hyphens, like |------|-----|
  @separator_regex ~r/^\|( ?-+ ?\|)+$/

  defp separator_or_comment_row?("#" <> _), do: true

  defp separator_or_comment_row?(row) do
    Regex.match?(@separator_regex, row)
  end

  defp file_meta(%{file: file, line: line}) when is_binary(file) and is_integer(line) do
    " (#{file}:#{line})"
  end

  defp file_meta(_), do: ""
end
