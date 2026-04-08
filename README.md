# ExPulp

A linear and mixed-integer programming (LP/MIP) modeler for Elixir, inspired by
Python's [PuLP](https://github.com/coin-or/PuLP).

ExPulp provides a macro-based DSL where arithmetic operators (`+`, `-`, `*`, `/`)
and comparisons (`>=`, `<=`, `==`) work directly on decision variables to build
constraints — so your model reads like the math.

## Quick Start

<!-- tabs-open -->

### Minimization

<!-- include: examples/quick_start.exs -->

```elixir
require ExPulp

problem = ExPulp.model "example", :minimize do
  x = var(low: 0, high: 10)
  y = var(low: 0, high: 10)

  minimize 2 * x + 3 * y
  subject_to "demand", x + y >= 5
end

{:ok, result} = ExPulp.solve(problem)
# result.status    => :optimal
# result.objective => 10.0
# result.variables => %{"x" => 5.0, "y" => 0.0}
```

### Knapsack (binary variables)

See [`Examples.Knapsack`](examples/knapsack.ex) for the full source.

```elixir
{problem, vars} = ExPulp.model "knapsack", :maximize do
  take = lp_binary_vars("take", items)

  maximize lp_weighted_sum(value, take)
  subject_to "capacity", lp_weighted_sum(weight, take) <= 15

  %{take: take}
end
```

### Transportation (multi-dimensional)

See [`Examples.Transportation`](examples/transportation.ex) for the full source.

```elixir
{problem, vars} = ExPulp.model "transport", :minimize do
  flow = lp_vars("flow", [sources, destinations], low: 0)

  minimize lp_sum(
    for s <- sources, d <- destinations, do: cost[{s, d}] * flow[{s, d}]
  )

  for s <- sources do
    subject_to "supply_#{s}",
      lp_sum(for d <- destinations, do: flow[{s, d}]) <= supply[s]
  end

  %{flow: flow}
end
```

<!-- tabs-close -->

## Features

- **Natural DSL** — write `2 * x + 3 * y >= 5` instead of building ASTs by hand
- **Auto-named variables** — `x = var(low: 0)` names the variable `"x"` from the assignment
- **Dynamic models** — `subject_to`, `minimize`, and `add_to_objective` work inside
  `for` loops, `if` blocks, and any nesting depth
- **Bulk variable creation** — `lp_vars("x", 1..100, low: 0)` and
  multi-dimensional `lp_vars("flow", [sources, destinations], low: 0)`
- **Weighted sums** — `lp_weighted_sum(costs, vars)` for the most common LP pattern
- **Incremental objectives** — call `add_to_objective` from multiple loops
- **Variable references returned** — end the block with a map to pass variable refs
  out for result extraction
- **Functional API** — build models with pipes when the DSL isn't a fit
- **CBC solver** — ships with [CBC](https://github.com/coin-or/Cbc) integration out of the box

## Examples

The `examples/` directory contains complete implementations of classic problems:

| Example | Problem Type | Source |
|---------|-------------|--------|
| **Whiskas** — cat food diet optimization | LP | [`Examples.Whiskas`](examples/whiskas.ex) |
| **Knapsack** — 0-1 item selection | MIP | [`Examples.Knapsack`](examples/knapsack.ex) |
| **Transportation** — network flow | LP | [`Examples.Transportation`](examples/transportation.ex) |
| **Sudoku** — constraint satisfaction | MIP | [`Examples.Sudoku`](examples/sudoku.ex) |

## Prerequisites

ExPulp requires the [CBC solver](https://github.com/coin-or/Cbc) to be installed
and available on your `PATH`.

```bash
# macOS
brew install cbc

# Ubuntu/Debian
apt-get install coinor-cbc
```

## Installation

Add `ex_pulp` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_pulp, "~> 0.1.0"}
  ]
end
```

## DSL Reference

Inside an `ExPulp.model` block, these forms are available:

| Form | Description |
|------|-------------|
| `var(opts)` | Create a variable (name auto-deduced from assignment) |
| `var("name", opts)` | Create a variable with explicit name |
| `lp_vars("prefix", indices, opts)` | Create indexed variable map |
| `lp_binary_vars("prefix", indices)` | Create indexed binary variables |
| `lp_integer_vars("prefix", indices, opts)` | Create indexed integer variables |
| `minimize expr` | Set the objective to minimize |
| `maximize expr` | Set the objective to maximize |
| `add_to_objective expr` | Add terms to the objective incrementally |
| `subject_to constraint` | Add a constraint (auto-named) |
| `subject_to "name", constraint` | Add a named constraint |
| `for_each enum, "prefix", fn i -> constraint end` | Bulk indexed constraints |
| `lp_sum(list)` | Sum variables/expressions |
| `lp_weighted_sum(coefficients, variables)` | Weighted sum from two maps |
| `lp_dot(coefficients, variables)` | Dot product from two lists |

## License

MIT
