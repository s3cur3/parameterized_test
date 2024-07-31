# Changelog

## v0.3.0

### New features

#### Support treating otherwise unparsable cells in your parameters table as strings

This is a quality of life improvement for avoiding needing to add noise to string cells:

```elixir
  param_test "supports unquoted strings",
             """
             | value   | unquoted string |
             | 1, 2, 3 | The value is 1  |
             """,
             %{value: value, "unquoted string": unquoted} do
    assert value == "1, 2, 3" and unquoted == "The value is 1"
  end
```

#### Support a "description" column that will provide a custom name for each test.

If you supply a column named `description`, `test_description`, or `test_desc`, we'll use that in the test name rather than simply dumping the values from the row in the test table. This lets you provide more human-friendly descriptions of why the test uses the values it does.

A trivial example (which also takes advantage of the support for unquoted strings):

```elixir
  param_test "failing test",
             """
             | value | description    |
             | 1     | The value is 1 |
             """,
             %{value: value} do
    assert value == 2
  end
```

When you run this, the error will include the description ("The value is 1") in the test name:

```
  1) test failing test - The value is 1 (MyAppTest)
     test/my_app_test.exs:8
     Assertion with == failed
     code:  assert value == 2
     left:  1
     right: 2
     stacktrace:
       test/my_app_test.exs:14: (test)
```

This is useful for communication with stakeholders, or for understanding what went wrong when a test fails.

## v0.2.0

There are two new features in this release thanks to new contributor @axelson:

* [Support longer test names](https://github.com/s3cur3/parameterized_test/pull/17)
* [Support comments and Obsidian markdown table format](https://github.com/s3cur3/parameterized_test/pull/16)

## v0.1.0

- Renamed to `ParameterizedTest`, with the accompanying macro `param_test`.
    (Why not `parameterized_test`? It's longer, harder to spell, and there are a lot of
    other accepted spellings, including "parameterised," "parametrized," and "parametrised.")
- Added support for hand-rolled lists of parameters, like:

    ```elixir
    param_test "shipping policy matches the web site",
                [
                  # Items in the parameters list can be either maps...
                  %{spending_by_category: %{pants: 29_99}, coupon:   "FREE_SHIP"},
                  # ...or keyword lists
                  [spending_by_category: %{shoes: 19_99, pants: 29_99}, coupon: nil]
                ],
                %{spending_by_category: spending_by_category, coupon: coupon} do
    ...
    end
    ```
- Added experimental support for populating test parameters from CSV and TSV files.
  Eventually I'd like to extend this to other sources like Notion documents. 
  (Feedback welcome—just open an issue!)

## v0.0.1

Initial release.
