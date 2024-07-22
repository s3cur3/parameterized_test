# Changelog

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
