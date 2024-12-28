defmodule ParameterizedTest.Parser do
  @moduledoc false
  @type context :: [{:line, integer} | {:file, String.t()}, ...]
  @type parsed_examples :: [{keyword(), context()}]

  defguardp is_valid_context(context) when is_list(context) and context != []

  @spec parse_examples(String.t() | list, context()) :: [{keyword(), context()}]
  def parse_examples(table, context \\ [])

  def parse_examples(table, context) when is_binary(table) and is_valid_context(context) do
    table
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> parse_md_rows(context)
  end

  # This function head handles a list of already-parsed examples, like:
  # param_test "accepts a list of maps or keyword lists",
  #            [
  #              [int_1: 99, int_2: 100],
  #              %{int_1: 101, int_2: 102}
  #            ], %{int_1: int_1, int_2: int_2} do
  def parse_examples(table, context) when is_list(table) and is_valid_context(context) do
    parse_hand_rolled_table(table, context)
  end

  @spec parse_file_path_examples(String.t(), context()) :: [map()]
  def parse_file_path_examples(path, context) when is_valid_context(context) do
    file = File.read!(path)

    context =
      context
      |> Keyword.put(:file, path)
      |> Keyword.put(:line, 1)

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

  # Returns an AST of sorts (not an offical Elixir AST) representing an example
  # table created with heredocs or a sigil, with the intended consumer being
  # the sigil formatter
  @spec example_table_ast(String.t(), list()) ::
          [
            {:cells, [String.t()]},
            {:separator, :padded | :unpadded},
            {:comment, String.t()}
          ]
  def example_table_ast(table, context \\ []) when is_binary(table) do
    table
    |> String.split("\n", trim: true)
    |> Enum.map(&String.trim/1)
    |> table_ast_rows(context)
  end

  defp description(kw_list) when is_list(kw_list) do
    kw_list
    |> Map.new()
    |> description()
  end

  defp description(%{test_description: desc}), do: desc
  defp description(%{test_desc: desc}), do: desc
  defp description(%{description: desc}), do: desc
  defp description(%{Description: desc}), do: desc
  defp description(_), do: nil

  defp parse_hand_rolled_table(evaled_table, context) when is_valid_context(context) do
    parsed_table =
      Enum.map(evaled_table, fn
        {values, context} when is_list(values) or is_map(values) -> {Keyword.new(values), context}
        other -> {Keyword.new(other), []}
      end)

    keys =
      parsed_table
      |> Enum.map(&elem(&1, 0))
      |> MapSet.new(&Keyword.keys/1)

    if MapSet.size(keys) > 1 do
      raise """
      The keys in each row must be the same across all rows in your example table.

      Found differing key sets#{file_meta(context)}:
      #{for key_set <- Enum.sort(keys), do: inspect(key_set)}
      """
    end

    parsed_table
  end

  defp parse_csv_file(file, context) when is_valid_context(context) do
    file
    |> ParameterizedTest.CsvParser.parse_string(skip_headers: false)
    |> parse_csv_rows(context)
  end

  defp parse_tsv_file(file, context) when is_valid_context(context) do
    file
    |> ParameterizedTest.TsvParser.parse_string()
    |> Enum.map(&String.trim/1)
    |> parse_csv_rows(context)
  end

  defp parse_md_rows(rows, context)
  defp parse_md_rows([], _context), do: []

  defp parse_md_rows([header | rows], context) when is_valid_context(context) do
    headers =
      header
      |> split_cells()
      |> Enum.map(&String.to_atom/1)

    rows
    # +1 to account for the header line.
    # Note that this may not be correct! In the ParameterizedTest.Backtrace module,
    # we'll use this as the place to start looking for the parameters line in the full
    # file contents (by reading the file and using the :raw context to find the text).
    |> Enum.with_index(context[:line] + 1)
    |> Enum.reject(fn {row, _index} -> row == "" or separator_or_comment_row?(row) end)
    |> Enum.map(fn {row, index} ->
      context =
        context
        |> Keyword.put(:min_line, index)
        |> Keyword.put(:raw, row)

      cells =
        row
        |> split_cells()
        |> Enum.map(&eval_cell(&1, row, context))

      check_cell_count!(cells, headers, row, context)

      {Enum.zip(headers, cells), context}
    end)
    |> Enum.reject(fn {row, _context} -> Enum.empty?(row) end)
  end

  defp parse_csv_rows(rows, context)
  defp parse_csv_rows([], _context), do: []

  defp parse_csv_rows([header | rows], context) when is_valid_context(context) do
    headers = Enum.map(header, &String.to_atom/1)

    rows
    |> Enum.map(fn row ->
      cells = Enum.map(row, &eval_cell(&1, row, context))

      check_cell_count!(cells, headers, row, context)

      Enum.zip(headers, cells)
    end)
    |> Enum.reject(&Enum.empty?/1)
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

  defp check_cell_count!(cells, headers, row, context) do
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

  defp table_ast_rows([header | _] = all_rows, context) do
    headers = split_cells(header)

    Enum.map(all_rows, fn row ->
      row
      |> classify_row()
      |> ast_parse_row()
      |> tap(fn
        {:cells, cells} -> check_cell_count!(cells, headers, row, context)
        _ -> nil
      end)
    end)
  end

  defp classify_row(row) do
    type =
      cond do
        separator_row?(row) -> :separator
        comment_row?(row) -> :comment
        true -> :cells
      end

    {type, row}
  end

  defp ast_parse_row({:cells, row}), do: {:cells, split_cells(row)}
  defp ast_parse_row({:comment, _} = row), do: row

  defp ast_parse_row({:separator, row}) do
    padding = if String.contains?(row, " "), do: :padded, else: :unpadded
    {:separator, padding}
  end

  defp split_cells(row) do
    row
    |> String.split("|", trim: true)
    |> Enum.map(&String.trim/1)
  end

  defp separator_or_comment_row?(row), do: separator_row?(row) or comment_row?(row)

  defp comment_row?(row), do: String.starts_with?(row, "#")

  # A regex to match rows consisting of pipes separated by hyphens, like |------|-----|
  @separator_regex ~r/^\|( ?-+ ?\|)+$/

  defp separator_row?(row), do: Regex.match?(@separator_regex, row)

  defp file_meta(%{file: file, line: line}) when is_binary(file) and is_integer(line) do
    " (#{file}:#{line})"
  end

  defp file_meta(_), do: ""
end
