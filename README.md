# ExampleTest

[![Hex.pm](https://img.shields.io/hexpm/v/example_test)](https://hex.pm/packages/example_test) [![Build and Test](https://github.com/s3cur3/example_test/actions/workflows/elixir-build-and-test.yml/badge.svg)](https://github.com/s3cur3/example_test/actions/workflows/elixir-build-and-test.yml) [![Elixir Quality Checks](https://github.com/s3cur3/example_test/actions/workflows/elixir-quality-checks.yml/badge.svg)](https://github.com/s3cur3/example_test/actions/workflows/elixir-quality-checks.yml) [![Code coverage](https://codecov.io/gh/s3cur3/example_test/graph/badge.svg)](https://codecov.io/gh/s3cur3/example_test)

A utility for defining eminently readable example-based tests in 
Elixir's ExUnit, inspired by [example tests in Cucumber](https://cucumber.io/docs/guides/10-minute-tutorial/?lang=java#using-variables-and-examples).

## What are example tests?

Example tests let you define variables along a number of dimensions 
and re-run the same test body (including all `setup`) for each 
combination of variables.

An extremely simple (perhaps too simple!) example:

```elixir
setup context do
  # context.permissions gets set by the example_test below
  permissions = Map.get(context, :permissions, nil)
  user = AccountsFixtures.user_fixture{permissions: permissions}
  %{user: user}
end

example_test "users can view the post regardless of permission level",
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
the `for` version is cleaner. But `example_test` supports an arbitrary
number of variables, so you can describe complex business rules like
"users get free shipping if they spend more than $100, or if they buy
socks, or if they have the right coupon code":

```elixir
example_test "grants free shipping based on the marketing site's stated policy",
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

## Why example testing?

Example testing reduces toil associated with writing tests that cover
a wide variety of different cases. It also localizes the test logic
into a single place, so that at a glance you can see how a number of
different factors affect the behavior of the system under test.

As a bonus, a table of examples (with their expected results) often
matches how the business communicates the requirements of a system,
both internally and to customers—for instance, in a table describing
shipping costs based on how much a customer spends, where they're
located, whether they've bought a promotional product, etc. This means
example tests can often be initially created by pulling directly from
a requirements document that your product folks provided, and the
product folks can later read the tests (or at least the examples table)
if they want to verify the behavior of the system.

### Example tests versus property tests

Example tests cover a lot of the same ground as property-based testing.
Both allow you to write fewer tests while covering more of your system's
behavior. This library is not a replacement for property tests, but
rather complimentary to them.

There are a few reasons you might choose to write an example
test rather than a property test:

- **Ease of writing**: Property tests take a lot of practice to get
  good at writing. They're often quite time consuming to produce, and
  even when you think you've adequately described the parameters to
  the system.
- **For communication with other stakeholders**: An example test
  table can be made readable by non-programmers (or non-Elixir 
  programmers), so they can be a good way of showing other people
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

- When you want the absolute highest confidence in your code.
- When the correctness of a piece of code is important enough to merit
  a large time investment in getting the tests right.
- When the system's behavior at the edges is well specified.

## Installation and writing your first test

1. Add `example_test` to your `mix.exs` dependencies:

    ```elixir
    def deps do
      [
        {:example_test, "~> 0.0.1", only: [:test]},
      ]
    end
    ```
2. Run `$ mix deps.get` to download the package
3. Write your first example test by adding `import ExampleTest` 
   to the top of your test module, and using the `example_test` macro.

   You can optionally include a separator between the header and body
   of the table (like `|--------|-------|`).

   The header of your table will be parsed as atoms to pass into your
   test context. The body cells of the table can be any valid Elixir 
   expression, and empty cells will produce a `nil` value.

   A dummy example:

    ```elixir
    defmodule MyApp.MyModuleTest do
      use ExUnit.Case, async: true
      import ExampleTest

      example_test "behaves as expected",
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
