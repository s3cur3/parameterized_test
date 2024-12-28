defmodule ParameterizedTest.Macros do
  @moduledoc false
  alias ParameterizedTest.Parser

  @doc false
  @spec escape_examples(String.t() | list, Parser.context()) :: Parser.parsed_examples() | keyword()
  def escape_examples(examples, context) do
    case examples do
      str when is_binary(str) ->
        file_extension =
          str
          |> Path.extname()
          |> String.downcase()

        case file_extension do
          ext when ext in [".md", ".markdown", ".csv"] ->
            Parser.parse_file_path_examples(str, context)

          _ ->
            Parser.parse_examples(str, context)
        end

      list when is_list(list) ->
        Parser.parse_examples(list, context)

      already_escaped when is_tuple(already_escaped) ->
        already_escaped
    end
  end
end
