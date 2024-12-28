defmodule ParameterizedTest.Backtrace do
  @moduledoc false
  alias ParameterizedTest.Parser

  @spec add_test_context(ExUnit.AssertionError.t(), [tuple()], Parser.context()) :: no_return()
  def add_test_context(%ExUnit.AssertionError{} = e, bt, context) do
    test_idx =
      Enum.find_index(bt, fn {_m, f, _arity, _context} ->
        f |> to_string() |> String.starts_with?("test ")
      end)

    {before_test, [test_line | after_test]} = Enum.split(bt, test_idx)

    {m, test_fun, _arity, _context} = test_line

    attributed_fun = function_to_attribute(test_fun, context)

    file_path = Path.relative_to(context[:file], File.cwd!())
    parameter_line = find_parameter_line(file_path, context)
    parameter_stack_frame = {m, attributed_fun, 0, [file: file_path, line: parameter_line]}
    reraise e, before_test ++ [test_line, parameter_stack_frame | after_test]
  end

  defp function_to_attribute(test_fun, context) do
    case context[:raw] do
      table_data when is_binary(table_data) and table_data != "" ->
        truncated_name =
          if String.length(table_data) > 128 do
            String.slice(table_data, 0..128) <> "..."
          else
            table_data
          end

        String.to_atom(truncated_name)

      _ ->
        test_fun
    end
  end

  # Reads through the file contents, using the raw content of the line that produced
  # this parameterized test, to find the exact line that contains the parameters.
  # This is necessary because there may be whitespace added between the `param_test` line
  # and the actual parameters which is not visible based on the information we get from
  # the macro context.
  defp find_parameter_line(path, context) do
    default = context[:min_line] || context[:line] || 0

    case {context[:raw], context[:min_line]} do
      {raw, min_line} when is_binary(raw) and raw != "" and is_integer(min_line) ->
        offset_from_min =
          path
          |> File.stream!(:line)
          |> Stream.drop(min_line - 1)
          |> Enum.find_index(&String.contains?(&1, raw))

        if is_nil(offset_from_min) do
          default
        else
          min_line + offset_from_min
        end

      _ ->
        default
    end
  end
end
