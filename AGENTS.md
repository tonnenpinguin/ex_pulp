# ExPulp — Agent Reference

Concise guide for LLM agents generating code that uses ExPulp.

## Setup

```elixir
# Always required before using the DSL macro
require ExPulp
```

## Core Pattern

```elixir
problem = ExPulp.model "name", :minimize do  # or :maximize
  x = var(low: 0, high: 10)                  # name auto-deduced as "x"
  y = var(low: 0)                             # unbounded above

  minimize 2 * x + 3 * y
  subject_to "label", x + y >= 5             # named constraint
  subject_to x <= 8                           # auto-named
end

{:ok, result} = ExPulp.solve(problem)
result.status     # :optimal | :infeasible | :unbounded | :not_solved
result.objective  # float
result.variables  # %{"x" => 5.0, "y" => 0.0}
```

## Returning Variable References

End the block with a map or tuple to get variable refs back for result extraction:

```elixir
{problem, vars} = ExPulp.model "name", :minimize do
  x = var(low: 0)
  minimize x
  subject_to x >= 5
  %{x: x}              # last expression is a map → returns {problem, map}
end

ExPulp.Result.evaluate(result, vars.x)  # use refs to extract values
```

If the last expression is NOT a map/tuple, returns just `%Problem{}`.

## Indexed Variables

```elixir
# 1D
vars = lp_vars("x", 1..100, low: 0)           # %{1 => %Variable{name: "x_1"}, ...}
vars = lp_vars("item", ["a", "b"], low: 0)     # %{"a" => %Variable{name: "item_a"}, ...}

# Multi-dimensional (tuple keys)
flow = lp_vars("f", [sources, destinations], low: 0)  # %{{:s1, :d1} => ..., ...}
flow[{:s1, :d1}]                                       # access by tuple key

# Shorthand for categories
bins = lp_binary_vars("select", items)
ints = lp_integer_vars("qty", 1..10, low: 0, high: 100)
```

## Building Objectives

```elixir
# Set at once
minimize 2 * x + 3 * y

# Or incrementally from loops
for i <- items do
  add_to_objective cost[i] * vars[i]
end
```

## Constraint Patterns

```elixir
# All of these work at ANY nesting depth (for, if, Enum.each, etc.)
subject_to "name", expr >= 5
subject_to expr <= 10          # auto-named
subject_to expr == 3           # equality

# Bulk constraints in loops
for i <- items do
  subject_to "cap_#{i}", vars[i] <= capacity[i]
end

# Or with for_each helper
for_each items, "cap", fn i -> vars[i] <= capacity[i] end
```

## Common Expressions

```elixir
lp_sum(for i <- items, do: vars[i])                # sum
lp_sum(for i <- items, do: cost[i] * vars[i])      # weighted sum via comprehension
lp_weighted_sum(cost_map, var_map)                  # weighted sum from two maps (same keys)
lp_dot([1, 2, 3], [x, y, z])                       # dot product from two lists
```

## Variable Categories

```elixir
x = var(low: 0)                          # continuous (default)
n = var(low: 0, high: 100, category: :integer)
b = var(category: :binary)               # integer with [0, 1] bounds
```

## Common Mistakes

1. **Forgetting `require ExPulp`** — the `model` macro needs it
2. **Using `==` for non-constraint equality inside the block** — `==` produces a constraint, not a boolean. Use `Kernel.==(a, b)` for actual equality checks
3. **Expecting operators to work outside the block** — `+`, `*`, `>=` etc. on variables only work inside `model do...end`. Outside, use `Expression.add/2`, `Constraint.geq/2` etc.
4. **Passing a Range directly to 1D `lp_vars`** — `lp_vars("x", 1..5)` works fine. Multi-dim needs a list of enumerables: `lp_vars("x", [1..3, 1..3])`
5. **Missing the `{problem, data}` return** — if you need variable refs after the block, end with a map. Otherwise you only get `%Problem{}` and must reconstruct names manually

## Functional API (no DSL)

```elixir
alias ExPulp.{Variable, Expression, Constraint, Problem}

x = Variable.new("x", low: 0, high: 10)
y = Variable.new("y", low: 0, high: 10)

problem = Problem.new("test", :minimize)
|> Problem.set_objective(Expression.new([{x, 1}, {y, 1}]))
|> Problem.add_constraint(Constraint.geq(Expression.new([{x, 1}, {y, 1}]), 5), "c1")

{:ok, result} = ExPulp.solve(problem)
```

## Result Inspection

```elixir
Result.optimal?(result)                    # true if optimal
Result.feasible?(result)                   # true if feasible
Result.get_variable(result, "x")           # get by name
Result.get_variable(result, var_struct)     # get by variable struct
Result.evaluate(result, expression)         # evaluate expression with solution values
```

## Solver

Requires `cbc` on PATH (`brew install cbc` / `apt install coinor-cbc`).

```elixir
ExPulp.solve(problem)                              # default CBC
ExPulp.solve(problem, time_limit: 60)              # with timeout
ExPulp.solve(problem, keep_files: true)             # keep .lp and .sol files
ExPulp.Solver.CBC.available?()                      # check if cbc is installed
```
