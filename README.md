# ParameterizedTest

[![Hex.pm](https://img.shields.io/hexpm/v/parameterized_test)](https://hex.pm/packages/parameterized_test) [![Build and Test](https://github.com/s3cur3/parameterized_test/actions/workflows/elixir-build-and-test.yml/badge.svg)](https://github.com/s3cur3/parameterized_test/actions/workflows/elixir-build-and-test.yml) [![Elixir Quality Checks](https://github.com/s3cur3/parameterized_test/actions/workflows/elixir-quality-checks.yml/badge.svg)](https://github.com/s3cur3/parameterized_test/actions/workflows/elixir-quality-checks.yml) [![Code coverage](https://codecov.io/gh/s3cur3/parameterized_test/graph/badge.svg)](https://codecov.io/gh/s3cur3/parameterized_test)

A utility for defining eminently readable parameterized (or example-based) tests in 
Elixir's ExUnit, inspired by [example tests in Cucumber](https://cucumber.io/docs/guides/10-minute-tutorial/?lang=java#using-variables-and-examples).

## What are parameterized tests?

Parameterized tests let you define variables along a number of dimensions 
and re-run the same test body (including all `setup`) for each 
combination of variables.

An extremely simple (perhaps too simple!) example:

```elixir
setup context do
  # context.permissions gets set by the param_test below
  permissions = Map.get(context, :permissions, nil)
  user = AccountsFixtures.user_fixture{permissions: permissions}
  %{user: user}
end

param_test "users can view the post regardless of permission level",
           """
           | permissions |
           |-------------|
           | :admin      |
           | :editor     |
           | :viewer     |
           | nil         |
           """,
           %{user: user, permissions: permissions} do
  assert Posts.can_view?(user), "User with #{permissions} permissions should be able to view"
end
```

That test will run 4 times, with the `:permissions` variable from the table 
being applied to the test's context each time (and therefore being made
available to the `setup` handler). Thus, under the hood this generates
four unique tests, equivalent to doing something like this:

```elixir
setup context do
  permissions = Map.get(context, :permissions, nil)
  user = AccountsFixtures.user_fixture{permissions: permissions}
  %{user: user}
end

for permission <- [:admin, :editor, :viewer, nil] do
  @permission permission

  @tag permission: @permission
  test "users with #{@permission} can view the post", %{user: user} do
    assert Posts.can_view?(user)
  end
end
```

Of course, that example only had a single variable, so you could argue
the `for` version is cleaner. But `parameterized_test` supports an arbitrary
number of variables, so you can describe complex business rules like
"users get free shipping if they spend more than $100, or if they buy
socks, or if they have the right coupon code":

```elixir
param_test "grants free shipping based on the marketing site's stated policy",
            """
            | spending_by_category          | coupon      | gets_free_shipping? |
            |-------------------------------|-------------|---------------------|
            | %{shoes: 19_99, pants: 29_99} |             | false               |
            | %{shoes: 59_99, pants: 49_99} |             | true                |
            | %{socks: 10_99}               |             | true                |
            | %{pants: 1_99}                | "FREE_SHIP" | true                |
            """,
            %{
               spending_by_category: spending_by_category,
               coupon: coupon,
               gets_free_shipping?: gets_free_shipping?
             } do
  shipping_cost = ShippingCalculator.calculate_shipping(spending_by_category, coupon)
  free_shipping? = shipping_cost == 0
  assert free_shipping? == gets_free_shipping?
end
```

## "I hate the Markdown table syntax!"

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
        {:parameterized_test, "~> 0.2", oly: [:test]},
      ]
    end
    ```
2. Run `$ mix deps.get` to download the package
3. Write your first example test by adding `import ParameterizedTest` 
   to the top of your test module, and using the `param_test` macro.

   You can optionally include a separator between the header and body
   of the table (like `|--------|-------|`).

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
                 |------------------|----------------------|---------|
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

## About test names

ExUnit requires each test in a module to have a unique name. To that end,
ParameterizedTest appends a stringified version of the parameters passed
to your test to the name you give the test. Consider this test:

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

- `"checks equality (%{val_1: :a, val_b: :a})"`
- `"checks equality (%{val_1: :b, val_b: :c})"`

And if you ran this test, you'd get an error that looks like this:

```
  1) test checks equality (%{val_1: :b, val_2: :c}) (MyModuleTest)
     test/my_module_test.exs:4
     Assertion with == failed
     code:  assert val_1 == val_2
     left:  :b
     right: :c
     stacktrace:
       test/my_module_test.exs:11: (test)
```
