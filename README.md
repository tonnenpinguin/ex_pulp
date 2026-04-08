# ExPulp

Linear and mixed-integer programming for Elixir.

Define optimization problems using natural arithmetic — `2 * x + 3 * y >= 5`
builds constraints directly from Elixir operators.

## Quick Start

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

## Prerequisites

ExPulp solves problems via the [CBC](https://github.com/coin-or/Cbc) solver,
which must be installed and on your `PATH`:

```bash
# macOS
brew install cbc

# Ubuntu/Debian
apt-get install coinor-cbc
```

## Installation

```elixir
def deps do
  [
    {:ex_pulp, "~> 0.1.0"}
  ]
end
```

## What It Looks Like

### Diet optimization (LP)

Find the cheapest blend of ingredients that meets nutritional requirements.
See the full source in [`Examples.Whiskas`](examples/whiskas.ex).

```elixir
{problem, vars} = ExPulp.model "whiskas", :minimize do
  v = lp_vars("ingr", ingredients, low: 0)

  minimize lp_weighted_sum(costs, v)

  subject_to "total",   lp_sum(for i <- ingredients, do: v[i]) == 100
  subject_to "protein", lp_weighted_sum(protein, v) >= 8.0
  subject_to "fat",     lp_weighted_sum(fat, v) >= 6.0

  %{v: v}
end
```

### 0-1 Knapsack (MIP)

Pick items to maximize value without exceeding weight capacity.
See [`Examples.Knapsack`](examples/knapsack.ex).

```elixir
{problem, vars} = ExPulp.model "knapsack", :maximize do
  take = lp_binary_vars("take", items)

  maximize lp_weighted_sum(value, take)
  subject_to "capacity", lp_weighted_sum(weight, take) <= 15

  %{take: take}
end
```

### Transportation (multi-dimensional LP)

Ship goods from factories to warehouses at minimum cost.
See [`Examples.Transportation`](examples/transportation.ex).

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

### Sudoku (constraint satisfaction)

Model a 9x9 Sudoku as a binary integer program.
See [`Examples.Sudoku`](examples/sudoku.ex).

All examples are tested against known optimal solutions — see `test/examples_test.exs`.

## DSL Reference

Inside an `ExPulp.model` block:

| Form | Description |
|------|-------------|
| `var(opts)` | Create a variable (name deduced from assignment) |
| `var("name", opts)` | Create a named variable |
| `lp_vars("prefix", indices, opts)` | Indexed variable map |
| `lp_binary_vars("prefix", indices)` | Indexed binary variables |
| `lp_integer_vars("prefix", indices, opts)` | Indexed integer variables |
| `minimize expr` | Set objective |
| `maximize expr` | Set objective |
| `add_to_objective expr` | Add to objective incrementally |
| `subject_to constraint` | Add constraint |
| `subject_to "name", constraint` | Add named constraint |
| `for_each enum, "prefix", fn -> constraint end` | Indexed constraints |
| `lp_sum(list)` | Sum expressions |
| `lp_weighted_sum(coeff_map, var_map)` | Weighted sum |
| `lp_dot(coeff_list, var_list)` | Dot product |

`minimize`, `subject_to`, `add_to_objective`, and `for_each` work at any nesting
depth — inside `for` loops, `if` blocks, comprehensions, etc.

End the block with a map or tuple to return variable references alongside the problem:

```elixir
{problem, %{x: x, y: y}} = ExPulp.model "name", :minimize do
  x = var(low: 0)
  y = var(low: 0)
  minimize x + y
  %{x: x, y: y}
end
```

A functional (non-DSL) API is also available — see [`ExPulp.Problem`](lib/ex_pulp/problem.ex) in the docs.

## License

MIT
