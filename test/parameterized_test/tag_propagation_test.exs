defmodule ParameterizedTest.TagPropagationTest do
  use ExUnit.Case, async: true

  import ParameterizedTest

  @rows [[row: 1], [row: 2], [row: 3]]

  @tag bare: true
  param_test "forwards a single keyword pair to every case", @rows, context do
    assert Map.take(context, [:bare]) == %{bare: true}
  end

  @tag :bare
  param_test "forwards an atom tag to every case", @rows, context do
    assert Map.take(context, [:bare]) == %{bare: true}
  end

  @tag first: 1, second: 2
  param_test "forwards every keyword pair to every case", @rows, context do
    assert Map.take(context, [:first, :second]) == %{first: 1, second: 2}
  end

  @tag :bare
  @tag single: :kept, first: :overridden
  @tag first: 1, second: 2
  param_test "forwards stacked tag declarations to every case", @rows, context do
    assert Map.take(context, [:bare, :single, :first, :second]) == %{
             bare: true,
             single: :kept,
             first: 1,
             second: 2
           }
  end
end
