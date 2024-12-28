# ParameterizedTest

[![Hex.pm](https://img.shields.io/hexpm/v/parameterized_test)](https://hex.pm/packages/parameterized_test) [![Build and Test](https://github.com/s3cur3/parameterized_test/actions/workflows/elixir-build-and-test.yml/badge.svg)](https://github.com/s3cur3/parameterized_test/actions/workflows/elixir-build-and-test.yml) [![Elixir Quality Checks](https://github.com/s3cur3/parameterized_test/actions/workflows/elixir-quality-checks.yml/badge.svg)](https://github.com/s3cur3/parameterized_test/actions/workflows/elixir-quality-checks.yml) [![Code coverage](https://codecov.io/gh/s3cur3/parameterized_test/graph/badge.svg)](https://codecov.io/gh/s3cur3/parameterized_test)

A utility for defining eminently readable parameterized (or example-based) tests in 
Elixir's ExUnit, inspired by [example tests in Cucumber](https://cucumber.io/docs/guides/10-minute-tutorial/?lang=java#using-variables-and-examples).

## What are parameterized tests?

Parameterized tests let you define variables along a number of dimensions 
and re-run the same test body (including all `setup`) for each 
combination of variables.

A simple example:

```elixir
setup context do
  # context.permissions gets set by the param_test below
  permissions = Map.get(context, :permissions, nil)
  user = AccountsFixtures.user_fixture(permissions: permissions)
  %{user: user}
end

param_test "users with editor permissions or better can edit posts",
           """
           | permissions | can_edit? | description                     |
           |-------------|-----------|---------------------------------|
           | :admin      | true      | Admins have max permissions     |
           | :editor     | true      | Editors can edit (of course!)   |
           | :viewer     | false     | Viewers are read-only           |
           | nil         | false     | Anonymous viewers are read-only |
           """,
           %{user: user, permissions: permissions, can_edit?: can_edit?} do
  assert Posts.can_edit?(user) == can_edit?, "#{permissions} permissions should grant edit rights"
end
```

That test will run 4 times, with the variables from from the table being applied 
to the test's context each time (and therefore being made
available to the `setup` handler). These variables are:

- `:permissions` 
- `:can_edit?`
- the special `:description` variable (see
  [About test names, and improving debuggability](#about-test-names-and-improving-debuggability)
  for how this is used)

Thus, under the hood this generates four unique tests,
equivalent to doing something like this:

```elixir
setup context do
  permissions = Map.get(context, :permissions, nil)
  user = AccountsFixtures.user_fixture{permissions: permissions}
  %{user: user}
end

for {permissions, can_edit?, description} <- [
        {:admin,  true,  "Admins have max permissions"},
        {:editor, true,  "Editors can edit (of course!)"},
        {:viewer, false, "Viewers are read-only"},
        {nil,     false, "Anonymous viewers are read-only"}
      ] do
    @permissions permissions
    @can_edit? can_edit?
    @description description

    @tag permissions: @permissions
    @tag can_edit?: @can_edit?
    @tag description: @description
    test "users with at least editor permissions can edit posts — #{@description}", %{user: user} do
      assert Posts.can_edit?(user) == @can_edit?
    end
  end
end
```

As you can see, even with only 3 variables (just 2 that impact the test semantics!),
the `for` comprehension comes with a lot of boilerplate. But the `param_test`
macro supports an arbitrary number of variables, so you can describe complex
business rules like "users get free shipping if they spend more than $100,
or if they buy socks, or if they have the right coupon code":

```elixir
param_test "grants free shipping based on the marketing site's stated policy",
            """
            | spending_by_category          | coupon      | ships_free? | description      |
            |-------------------------------|-------------|-------------|------------------|
            | %{shoes: 19_99, pants: 29_99} |             | false       | Spent too little |
            | %{shoes: 59_99, pants: 49_99} |             | true        | Spent over $100  |
            | %{socks: 10_99}               |             | true        | Socks ship free  |
            | %{pants: 1_99}                | "FREE_SHIP" | true        | Correct coupon   |
            | %{pants: 1_99}                | "FOO"       | false       | Incorrect coupon |
            """,
            %{
               spending_by_category: spending_by_category,
               coupon: coupon,
               ships_free?: ships_free?
             } do
  shipping_cost = ShippingCalculator.calculate(spending_by_category, coupon)
  
  if ships_free? do
    assert shipping_cost == 0
  else
    assert shipping_cost > 0
  end
end
```

The package also provides a second macro, `param_feature`, which wraps
Wallaby's `feature` tests the same way `param_test` wraps ExUnit's `test`.
(While you _can_ use the plain `param_test` macro in a test module that
contains `use Wallaby.Feature`, doing so will break some Wallaby features
including screenshot generation on failure.)

## Why parameterized testing?

Parameterized testing reduces toil associated with writing tests that cover
a wide variety of different example cases. It also localizes the test logic
into a single place, so that at a glance you can see how a number of
different factors affect the behavior of the system under test.

As a bonus, a table of examples (with their expected results) often
matches how the business communicates the requirements of a system,
both internally and to customers—for instance, in a table describing
shipping costs based on how much a customer spends, where they're
located, whether they've bought a promotional product, etc. This means
parameterized tests can often be initially created by pulling directly from
a requirements document that your product folks provide, and the
product folks can later read the tests (or at least the parameters table)
if they want to verify the behavior of the system.

### Parameterized tests versus property tests

Parameterized tests are superficially similar to property-based tests.
Both allow you to write fewer tests while covering more of your system's
behavior. This library is not a replacement for property tests, but
rather complimentary to them.

There are a few reasons you might choose to write a parameterized
test rather than a property test:

- **When describing policies, not invariants**: Much of a system's
  business logic comes down to arbitrary choices made by a product team.
  For instance, there's nothing in the abstract description of a shipping
  calculator that says buying socks or spending $100 total should grant
  you free shipping. Those aren't *principles* that every correctly
  implemented shipping system would implement. Instead, they're choices
  made by someone (maybe a product manager) which will in all likelihood
  be fiddled with over time.
  
  Contrast that with the classic use cases for property tests: every 
  (correct) implementation of, say, `List.sort/1` will *always* have
  the dual properties of:
  
  1. every element of the input being represented in the output, and 
  2. every element being "less than" the element after it.

  These sorting properties are *invariants* of the sorting function,
  and therefore are quite amenable to property testing.
- **Ease of writing**: Property tests take a lot of practice to get
  good at writing. They're often quite time consuming to produce, and
  even when you think you've adequately described the parameters to
  the system.
- **For communication with other stakeholders**: The table of examples
  in a parameterized test can be made readable by non-programmers (or 
  non-Elixir  programmers), so they can be a good way of showing others
  in your organization which behaviors of the system you've verified.
  Because they can compactly express a lot of test cases, they're
  much more suitable for this than saying "go read the title of
  every line in this file that starts with `test`."
- **For verifying the exact scenarios described by other stakeholders**:
  Sometimes the edges of a particular behavior may be fuzzy—not just
  to you, but in the business domain as well. Hammering out hard-and-fast
  rules may not be necessary or worth it, so property tests that exercise
  the boundaries would be overkill. In contrast, when your product
  folks produce a document that describes the behavior of particular
  scenarios, you can encode that in a table and ensure that for the
  cases that are well-specified, the system behaves correctly.

When would you write a property test instead of an example tests?

- When you can specify true invariants about the desired behavior
- When you want the absolute highest confidence in your code
- When the correctness of a piece of code is important enough to merit
  a large time investment in getting the tests right
- When the system's behavior at the edges is well specified

And of course there's nothing wrong with using a mix of normal tests,
parameterized tests, and property tests for a given piece of functionality.

## Installation and writing your first test

1. Add `parameterized_test` to your `mix.exs` dependencies:

    ```elixir
    def deps do
      [
        {:parameterized_test, "~> 0.6", only: [:test]},
      ]
    end
    ```
2. Run `$ mix deps.get` to download the package
3. Write your first example test by adding `import ParameterizedTest` 
   to the top of your test module, and using the `param_test` macro.

   You can optionally include a separator between the header and body
   of the table (like `|--------|-------|`), and a `description` column
   to improve the errors you get when your test fails (see
   [About test names, and improving debuggability](#about-test-names-and-improving-debuggability)
   for more on descriptions).

   The header of your table will be parsed as atoms to pass into your
   test context. The body cells of the table can be any valid Elixir 
   expression, and empty cells will produce a `nil` value.

   A dummy example:

    ```elixir
    defmodule MyApp.MyModuleTest do
      use ExUnit.Case, async: true
      import ParameterizedTest

      param_test "behaves as expected",
                 """
                 | variable_1       | variable_2           | etc     |
                 | ---------------- | -------------------- | ------- |
                 | %{foo: :bar}     | div(19, 3)           | false   |
                 | "bip bop"        | String.upcase("foo") | true    |
                 | ["whiz", "bang"] | :ok                  |         |
                 |                  | nil                  | "maybe" |
                 """,
                 %{
                   variable_1: variable_1,
                   variable_2: variable_2,
                   etc: etc
                 } do
          assert MyModule.valid_combination?(variable_1, variable_2, etc)
        end
    end
    ```


## Debugging failing tests 

As of v0.6.0, when you get a test failure, the backtrace that ExUnit prints will include
the line in your file that provided the failing parameters. For instance, consider
this test that will fail 100% of the time:

```elixir
param_test "gives the failing parameter row when a test fails",
            """
            | should_fail? | description |
            | false        | "Works"     |
            | true         | "Breaks"    |
            """,
            %{should_fail?: should_fail?} do
  refute should_fail?
end
```

When you run it, you'll get an ExUnit backtrace that looks like this:

```
  1) test gives the failing parameter row when a test fails - Breaks (ParameterizedTest.BacktraceTest)
     test/parameterized_test/backtrace_test.exs:1
     Expected truthy, got false
     code: assert not should_fail?
     stacktrace:
       test/parameterized_test/backtrace_test.exs:8: (test)
       test/parameterized_test/backtrace_test.exs:5: ParameterizedTest.BacktraceTest."| true         | \"Breaks\"    |"/0
```

Use this line number to figure out which of your parameter rows caused the failing test.

### About test names, and improving debuggability

ExUnit requires each test in a module to have a unique name. By default,
without a `description` for the rows in your parameters table, 
`ParameterizedTest` appends a stringified version of the parameters
passed to your test to the name you give the test. Consider this test:

```elixir
param_test "checks equality",
            """
            | val_1 | val_2 |
            | :a    | :a    |
            | :b    | :c    |
            """,
            %{val_1: val_1, val_2: val_2} do
  assert val_1 == val_2
end
```

Under the hood, this produces two tests with the names:

- `"checks equality ([val_1: :a, val_b: :a])"`
- `"checks equality ([val_1: :b, val_b: :c])"`

And if you ran this test, you'd get an error that looks like this:

```
  1) test checks equality ([val_1: :b, val_2: :c]) (MyModuleTest)
     test/my_module_test.exs:4
     Assertion with == failed
     code:  assert val_1 == val_2
     left:  :b
     right: :c
     stacktrace:
       test/my_module_test.exs:11: (test)
```

You can improve the names in the failure cases by providing a `description`
column. When provided, that column will be used in the name. You may want
to use this to explain *why* this combination of values should produce
the expected outcome; for instance:

```elixir
param_test "grants free shipping for spending $99 or more, or with coupon FREE_SHIP",
           """
           | total_cents | coupon      | free? | description                 |
           | ----------- | ----------- | ----- | --------------------------- |
           | 98_99       |             | false | Spent too little            |
           | 99_00       |             | true  | Min for free shipping       |
           | 99_01       |             | true  | Spent more than the minimum |
           | 1_00        | "FREE_SHIP" | true  | Had the right coupon        |
           | 1_00        | "FOO"       | false | Unrecognized coupon         |
           """, %{total_cents: total_cents, coupon: coupon, free?: gets_free_shipping?} do
  shipping_cost = ShippingCalculator.calculate(total_cents, coupon)
  free_shipping? = shipping_cost == 0
  assert free_shipping? == gets_free_shipping?
end
```

Suppose in your `ShippingCalculator` implementation, you mistakenly set 
the free shipping threshold to be _greater_ than $99.00, when your web site's
state policy was $99 or more. You'd get an error when running this test that
looks like this (note the first line ends with "Spent the min. for free shipping" from the `description` column):

```
  1) test grants free shipping for spending $99 or more, or with coupon FREE_SHIP - Spent the min. for free shipping (ShippingCalculatorTest)
     test/shipping/shipping_calculator_test.exs:34
     Assertion with == failed
     code:  assert free_shipping? == gets_free_shipping?
     left:  false
     right: true
     stacktrace:
       test/shipping/shipping_calculator_test.exs:47: (test)
```


## Objections

### Why not just use the new `:parameterize` feature built into ExUnit in Elixir 1.18?

Both this package and the
[new, built-in parameterization](https://hexdocs.pm/ex_unit/main/ExUnit.Case.html#module-parameterized-tests)
do similar things: they re-run the same test body with a different set of
parameters. However, the built-in parameterization works by re-running 
your entire test module with each parameter set, so it's primarily aimed
at cases where the tests should work the same regardless of the parameters.
(The docs give the example of testing the `Registry` module and expecting
it to behave the same regardless of how many partitions are used.)

In contrast, the `param_test` macro is designed to use different parameters
on a per-test basis, and it's expected that the parameters will cause different
behavior between the test runs (and you'd generally expect to see one column
that describes what the results should be).

Finally, of course, there's the format of a `param_test`. The tabular, often
quite human-friendly format encourages collaboration with less technical
people on your team; your product manager may not be able to read a `for`
comprehension, but if you link them to a Markdown table on GitHub that shows
the test cases you've covered, they can probably make sense of them.

### "I hate the Markdown table syntax!"

No sweat, you don't have to use it. You can instead pass a hand-rolled list of
parameters to the `param_test` macro, like this:

```elixir
param_test "shipping policy matches the web site",
            [
              # Items in the parameters list can be either maps...
              %{spending_by_category: %{pants: 29_99}, coupon: "FREE_SHIP"},
              # ...or keyword lists
              [spending_by_category: %{shoes: 19_99, pants: 29_99}, coupon: nil]
            ],
            %{spending_by_category: spending_by_category, coupon: coupon} do
  ...
end
```

Just make sure that each item in the parameters list has the same keys.

The final option is to pass a path to a *file* that contains your test parameters (we currently support `.md`/`.markdown`, `.csv`, and `.tsv` files), like this:

```elixir
param_test "pull test parameters from a file",
            "test/fixtures/params.md",
            %{
              spending_by_category: spending_by_category,
              coupon: coupon,
              gets_free_shipping?: gets_free_shipping?
            } do
  ...
end
```
