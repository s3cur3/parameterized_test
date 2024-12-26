# Changelog

## v0.5.1

- [Support `@tag` module attributes applied to `param_test` or `param_feature` blocks](https://github.com/s3cur3/parameterized_test/pull/40)

## v0.5.0

- New Mix formatter plugin for formatting the package's sigils, courtesy of @rschenk (🎉). To enable it, in your `formatter.exs`, add to following:
    ```elixir
      plugins: [
        ParameterizedTest.Formatter,
      ],
    ```
You can see a brief video demo [on the PR](https://github.com/s3cur3/parameterized_test/pull/32).
- Fixed an issue (#31) where `mix test --failed` could fail to run previously-failing tests because the way we were adding the parameters to the name (as a map) was not stable across runs. The consequence of this change is that the names of tests missing a description will change from listing parameters as maps to lists.
    - Example: suppose you previously have a `param_test` called `"checks equality"` with parameters `val_1: :a` and `val_b: :b`. It would previously have been given the full name `"checks equality (%{val_1: :a, val_2: :b})"` *or* `"checks equality (%{val_2: :b, val_1: :a})"`, and which you saw would change between test runs. In this release, it will consistently be given the name `"checks equality ([val_1: :a, val_2: :b])"`.

## v0.4.0

- Adds a new `param_feature` macro, which wraps Wallaby's `feature` tests
  the same way `param_test` wraps ExUnit's `test`.

  (While you _can_ use the plain `param_test` macro in a test module that
  contains `use Wallaby.Feature`, doing so will break some Wallaby features
  including screenshot generation on failure.)
- Moves the `parse_examples/2` function, an implementation detail for the
  `param_test` macro, into a new private module `ParameterizedTest.Parser`.

## v0.3.1

Bug fix to accept more unquoted strings, including those that have Elixir delimiters in them like quotes, parentheses, etc.

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
