defmodule ParameterizedTest.ParserTest do
  use ExUnit.Case, async: true

  describe "parse_examples/1" do
    test "accepts strings that parse as empty" do
      for empty <- ["", " ", "\n", "\t", "\r\n", "\n\n \r\n \t \r"] do
        assert ParameterizedTest.Parser.parse_examples(empty) == []
      end
    end
  end
end
