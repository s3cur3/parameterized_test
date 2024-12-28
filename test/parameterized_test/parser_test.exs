defmodule ParameterizedTest.ParserTest do
  use ExUnit.Case, async: true

  describe "parse_examples/1" do
    test "accepts strings that parse as empty" do
      for empty <- ["", " ", "\n", "\t", "\r\n", "\n\n \r\n \t \r"] do
        assert ParameterizedTest.Parser.parse_examples(empty, file: __ENV__.file, line: __ENV__.line) == []
      end
    end
  end

  describe "example_table_ast/1" do
    test "returns a representation of the raw values in an example table" do
      assert ParameterizedTest.Parser.example_table_ast("""
             | a        | b           |
             |----------|-------------|
             | "string" | :atom       |
             # comment
             | 123      | %{d: [1.0]} |
             |          | ""          |
             """) == [
               {:cells, ["a", "b"]},
               {:separator, :unpadded},
               {:cells, ["\"string\"", ":atom"]},
               {:comment, "# comment"},
               {:cells, ["123", "%{d: [1.0]}"]},
               {:cells, ["", "\"\""]}
             ]
    end
  end
end
