defmodule ParameterizedTest.Parser do
  @moduledoc false
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

  @spec parse_file_path_examples(String.t(), context()) :: [map()]
  def parse_file_path_examples(path, context) do
    file = File.read!(path)

    case path |> Path.extname() |> String.downcase() do
      md when md in [".md", ".markdown"] -> parse_examples(file, context)
      ".csv" -> parse_csv_file(file, context)
      ".tsv" -> parse_tsv_file(file, context)
      _ -> raise "Unsupported file extension for parameterized tests #{path} #{file_meta(context)}"
    end
  end

  @spec full_test_name(String.t(), map(), integer, integer) :: String.t()
  def full_test_name(original_test_name, example, row_index, max_chars) do
    custom_description = description(example)

    un_truncated_name =
      case custom_description do
        nil -> "#{original_test_name} (#{inspect(example)})"
        desc -> "#{original_test_name} - #{desc}"
      end

    cond do
      String.length(un_truncated_name) <= max_chars -> un_truncated_name
      is_nil(custom_description) -> "#{original_test_name} row #{row_index}"
      true -> String.slice(un_truncated_name, 0, max_chars)
    end
  end

  defp description(%{test_description: desc}), do: desc
  defp description(%{test_desc: desc}), do: desc
  defp description(%{description: desc}), do: desc
  defp description(%{Description: desc}), do: desc
  defp description(_), do: nil

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
    case Code.eval_string(cell, [], log: false) do
      {val, []} -> val
      _ -> raise "Failed to evaluate example cell `#{cell}` in row `#{row}`}"
    end
  rescue
    _e in [SyntaxError, CompileError, TokenMissingError] ->
      String.trim(cell)

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
