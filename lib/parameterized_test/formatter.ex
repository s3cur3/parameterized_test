defmodule ParameterizedTest.Formatter do
  @moduledoc false
  @behaviour Mix.Tasks.Format

  def features(_opts) do
    sigil = if Version.match?(System.version(), "< 1.15.0"), do: :x, else: :PARAMS

    [sigils: [sigil], extensions: []]
  end

  def format(contents, _opts) do
    contents
    |> ParameterizedTest.Parser.example_table_ast()
    |> format_table()
  end

  defp format_table(rows) do
    [header | _] =
      table_cells =
      rows
      |> Enum.filter(&match?({:cells, _}, &1))
      |> Enum.map(&elem(&1, 1))

    column_widths =
      Enum.reduce(table_cells, List.duplicate(0, length(header)), fn row_cells, acc ->
        row_cells
        |> Enum.map(&String.length/1)
        |> Enum.zip(acc)
        |> Enum.map(fn {a, b} -> max(a, b) end)
      end)

    Enum.map_join(rows, "\n", &format_row(&1, column_widths)) <> "\n"
  end

  defp format_row({:comment, c}, _widths), do: c

  defp format_row({:separator, pad_type}, widths) do
    padding =
      case pad_type do
        :padded -> " "
        :unpadded -> "-"
      end

    widths
    |> Enum.map_join("|", fn w ->
      [padding, String.duplicate("-", w), padding]
    end)
    |> borders()
  end

  defp format_row({:cells, cells}, widths) do
    cells
    |> Enum.zip(widths)
    |> Enum.map_join("|", fn {cell, w} -> " #{String.pad_trailing(cell, w)} " end)
    |> borders()
  end

  defp borders(str), do: "|#{str}|"
end
