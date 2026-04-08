# ExPulp

[![Hex.pm](https://img.shields.io/hexpm/v/ex_pulp.svg)](https://hex.pm/packages/ex_pulp)
[![HexDocs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/ex_pulp)

Linear, mixed-integer, and quadratic programming for Elixir, inspired by
Python's [PuLP](https://github.com/coin-or/PuLP).

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

ExPulp requires [HiGHS](https://highs.dev) (default) or [CBC](https://github.com/coin-or/Cbc)
on your `PATH`. HiGHS supports LP, MIP, and QP. CBC supports LP and MIP.

```bash
# macOS
brew install highs    # recommended
brew install cbc      # alternative

# Ubuntu/Debian
apt-get install coinor-cbc
# HiGHS: download from https://github.com/ERGO-Code/HiGHS/releases
```

## Installation

```elixir
def deps do
  [
    {:ex_pulp, "~> 0.1.0"}
  ]
end
```

## Examples

### Diet optimization (LP)

Find the cheapest blend of ingredients that meets nutritional requirements.
See [`Examples.Whiskas`](examples/whiskas.ex).

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

### Portfolio optimization (QP)

Minimize portfolio variance subject to a target return.
See [`Examples.Portfolio`](examples/portfolio.ex).

```elixir
{problem, vars} = ExPulp.model "portfolio", :minimize do
  w = lp_vars("w", assets, low: 0, high: 1)

  minimize lp_sum(for i <- assets, j <- assets, do: cov[{i, j}] * w[i] * w[j])

  subject_to "invested", lp_sum(for i <- assets, do: w[i]) == 1
  subject_to "return",   lp_weighted_sum(returns, w) >= 0.10

  %{w: w}
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

All DSL forms work at any nesting depth — inside `for` loops, `if` blocks,
comprehensions, and function calls.

End the block with a map or tuple to return variable references alongside the problem:

```elixir
{problem, %{x: x, y: y}} = ExPulp.model "name", :minimize do
  x = var(low: 0)
  y = var(low: 0)
  minimize x + y
  %{x: x, y: y}
end
```

A pipe-based functional API is also available — see `ExPulp.Problem` in the docs.

## License

MIT
