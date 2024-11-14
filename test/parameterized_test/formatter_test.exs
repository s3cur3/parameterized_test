defmodule ParameterizedTest.FormatterTest do
  use ExUnit.Case, async: true

  describe "format/2" do
    test "formats a table" do
      input =
        """
        |a|b|
        | - | - |
        |"string"|:atom|
        |123|%{d: [1.0]}|
        # comment
        | | "" |
        """

      expected_output =
        """
        | a        | b           |
        | -------- | ----------- |
        | "string" | :atom       |
        | 123      | %{d: [1.0]} |
        # comment
        |          | ""          |
        """

      assert ParameterizedTest.Formatter.format(input, []) == expected_output
    end

    test "respects unpadded separator rows" do
      input =
        """
        |a|b|
        |-|-|
        |"string"|:atom|
        |123|%{d: [1.0]}|
        # comment
        | | "" |
        """

      expected_output =
        """
        | a        | b           |
        |----------|-------------|
        | "string" | :atom       |
        | 123      | %{d: [1.0]} |
        # comment
        |          | ""          |
        """

      assert ParameterizedTest.Formatter.format(input, []) == expected_output
    end

    test "works when the table is too wide also" do
      input =
        """
        | a        | b        |
        |---------------|-------------|
        | "string" | :atom  |
        | 123      | %{d: [1.0]} |
        # comment
        |          | ""       |
        """

      expected_output =
        """
        | a        | b           |
        |----------|-------------|
        | "string" | :atom       |
        | 123      | %{d: [1.0]} |
        # comment
        |          | ""          |
        """

      assert ParameterizedTest.Formatter.format(input, []) == expected_output
    end
  end
end
