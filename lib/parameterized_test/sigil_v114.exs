defmodule ParameterizedTest.Sigil do
  @moduledoc """
  Provides a sigil to wrap parsing of the example test tables.

  Note that on Elixir v1.15.0 and later, the sigil is named `~PARAMS`.
  Elixir v1.14 and earlier use `~x` since those versions don't support
  multi-character or uppercase sigils.

  The `param_test` macro automatically parses Markdown-style example tables
  into a list of maps for use in the test contexts, so this sigil is never
  *required* to be used. However, it may occasionally be useful to do things
  like declare a module attribute which is the pre-parsed example table, or to
  inspect how the table will be parsed.
  """

  @doc ~S"""
  Provides a sigil for producing example data that you can use in tests.

  ### Examples

  You can have an arbitrary number of columns and rows. Headers are parsed
  as atoms, while the individual cells are parsed as Elixir values.

      iex> ~x\"""
      ...>   | plan      | user_permission | can_invite?     |
      ...>   | :free     | :admin          | true            |
      ...>   | :free     | :editor         | "maybe"         |
      ...>   | :free     | :view_only      | false           |
      ...>   | :standard | :admin          | true            |
      ...>   | :standard | :editor         | "tuesdays only" |
      ...>   | :standard | :view_only      | false           |
      ...> \"""
      [
        %{plan: :free, user_permission: :admin, can_invite?: true},
        %{plan: :free, user_permission: :editor, can_invite?: "maybe"},
        %{plan: :free, user_permission: :view_only, can_invite?: false},
        %{plan: :standard, user_permission: :admin, can_invite?: true},
        %{plan: :standard, user_permission: :editor, can_invite?: "tuesdays only"},
        %{plan: :standard, user_permission: :view_only, can_invite?: false}
      ]

  You can optionally include separators between the headers and the data.

      iex> ~x\"""
      ...>   | plan      | user_permission | can_invite?     |
      ...>   |-----------|-----------------|-----------------|
      ...>   | :free     | :admin          | true            |
      ...>   | :free     | :editor         | "maybe"         |
      ...> \"""
      [
        %{plan: :free, user_permission: :admin, can_invite?: true},
        %{plan: :free, user_permission: :editor, can_invite?: "maybe"}
      ]
  """
  @spec sigil_x(String.t(), Keyword.t()) :: [map()]
  # credo:disable-for-next-line Credo.Check.Readability.FunctionNames
  def sigil_x(table, _opts \\ []) do
    ParameterizedTest.Parser.parse_examples(table)
  end
end
