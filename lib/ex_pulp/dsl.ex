defmodule ExPulp.DSL do
  @moduledoc """
  Provides the `model/3` macro for defining LP/MIP problems with natural syntax.

  Inside a `model` block, arithmetic operators (`+`, `-`, `*`, `/`) and
  comparison operators (`>=`, `<=`, `==`) are overridden to work on
  variables and expressions, producing constraint structs.

  `minimize`, `maximize`, `subject_to`, and `for_each` work at any nesting
  depth -- inside `for` loops, `if` blocks, helper function calls, etc.

  ## Example

      problem = ExPulp.model "test", :minimize do
        x = var(low: 0, high: 10)
        y = var(low: 0, high: 10)

        minimize x + y

        for i <- [5, 10] do
          subject_to x + y >= i
        end
      end

      {:ok, result} = ExPulp.solve(problem)

  ## Returning variable references

  If the last expression in the block is a map or tuple, the model returns
  `{problem, data}` so you can pass variable references out for result extraction:

      {problem, vars} = ExPulp.model "test", :minimize do
        x = var(low: 0, high: 10)
        y = var(low: 0, high: 10)
        minimize x + y
        subject_to x + y >= 5
        %{x: x, y: y}
      end

      {:ok, result} = ExPulp.solve(problem)
      ExPulp.Result.evaluate(result, vars.x + vars.y)

  Variable names are automatically deduced from the left-hand side of the
  assignment (`x = var(...)` names the variable `"x"`). You can override
  this with a `:name` option: `x = var(name: "custom", low: 0)`.

  ## DSL Forms

  The following forms are available inside a `model` block:

    * `var/1`, `var/2` - Create a decision variable with optional bounds and category
    * `minimize/1` - Set the objective function to minimize
    * `maximize/1` - Set the objective function to maximize
    * `subject_to/1`, `subject_to/2` - Add a constraint (optionally named)
    * `add_to_objective/1` - Incrementally add terms to the objective
    * `for_each/2`, `for_each/3` - Add indexed constraints from an enumerable
    * `lp_sum/1` - Sum a list of variables/expressions (like PuLP's `lpSum`)
    * `lp_vars/3` - Create a map of indexed variables (like PuLP's `LpVariable.dicts`)
    * `lp_binary_vars/2` - Create indexed binary variables
    * `lp_integer_vars/3` - Create indexed integer variables
    * `lp_dot/2` - Compute the dot product of coefficients and variables
  """

  @builder_key :expulp_builder

  @doc """
  Defines a linear programming model.

  The `name` is a string identifier for the problem. The `sense` is either
  `:minimize` or `:maximize`. The block contains variable definitions,
  an objective (via `minimize` or `maximize`), and constraints (via `subject_to`).

  If the last expression in the block is a map or tuple, returns
  `{%Problem{}, data}`. Otherwise returns `%Problem{}`.
  """
  defmacro model(name, sense, do: block) do
    transformed = transform_block(block)

    quote do
      (fn ->
         import Kernel,
           except: [+: 2, -: 2, *: 2, /: 2, >=: 2, <=: 2, ==: 2, -: 1]

         import ExPulp.DSL.Operators
         import ExPulp.DSL.Helpers

         import ExPulp.DSL,
           only: [
             minimize: 1,
             maximize: 1,
             subject_to: 1,
             subject_to: 2,
             for_each: 2,
             for_each: 3,
             add_to_objective: 1
           ]

         ExPulp.DSL.init_builder(unquote(name), unquote(sense))

         expulp_last_expr = unquote(transformed)

         ExPulp.DSL.finish_builder(expulp_last_expr)
       end).()
    end
  end

  # --- Runtime builder functions (work at any nesting depth) ---

  @doc false
  def init_builder(name, sense) do
    if Process.get(@builder_key) do
      raise "ExPulp.model blocks cannot be nested"
    end

    Process.put(@builder_key, ExPulp.DSL.Builder.new(name, sense))
  end

  @doc false
  def finish_builder(last_expr) do
    builder = Process.delete(@builder_key)
    problem = ExPulp.DSL.Builder.to_problem(builder)

    case last_expr do
      data when is_map(data) and not is_struct(data) -> {problem, data}
      data when is_tuple(data) -> {problem, data}
      _ -> problem
    end
  end

  defp update_builder(fun) do
    builder = Process.get(@builder_key)
    Process.put(@builder_key, fun.(builder))
    :ok
  end

  @doc """
  Sets the objective function. Can be called from any nesting depth inside a `model` block.
  """
  def minimize(expr) do
    update_builder(fn builder ->
      if builder.sense != :minimize do
        raise ArgumentError, "called minimize/1 inside a :maximize model — use maximize/1"
      end

      ExPulp.DSL.Builder.set_objective(builder, expr)
    end)
  end

  @doc """
  Sets the objective function. Can be called from any nesting depth inside a `model` block.
  """
  def maximize(expr) do
    update_builder(fn builder ->
      if builder.sense != :maximize do
        raise ArgumentError, "called maximize/1 inside a :minimize model — use minimize/1"
      end

      ExPulp.DSL.Builder.set_objective(builder, expr)
    end)
  end

  @doc """
  Adds a named constraint. Can be called from any nesting depth inside a `model` block.
  """
  def subject_to(name, %ExPulp.Constraint{} = constraint) do
    update_builder(&ExPulp.DSL.Builder.add_constraint(&1, constraint, name))
  end

  @doc """
  Adds an unnamed constraint. Can be called from any nesting depth inside a `model` block.
  """
  def subject_to(%ExPulp.Constraint{} = constraint) do
    update_builder(&ExPulp.DSL.Builder.add_constraint(&1, constraint))
  end

  @doc """
  Adds expression terms to the objective. Can be called multiple times to
  build the objective incrementally.

      add_to_objective phase1_cost
      add_to_objective phase2_cost
  """
  def add_to_objective(expr) do
    update_builder(&ExPulp.DSL.Builder.add_to_objective(&1, expr))
  end

  @doc """
  Adds indexed constraints from an enumerable with a name prefix.

      for_each 1..10, "cap", fn i -> flow[i] <= capacity[i] end
  """
  def for_each(enumerable, prefix, func) do
    Enum.each(enumerable, fn item ->
      constraint = func.(item)
      subject_to("#{prefix}_#{item}", constraint)
    end)
  end

  @doc """
  Adds indexed constraints from an enumerable (auto-named).

      for_each 1..10, fn i -> flow[i] >= 0 end
  """
  def for_each(enumerable, func) do
    Enum.each(enumerable, fn item ->
      constraint = func.(item)
      subject_to(constraint)
    end)
  end

  # --- AST transformation (only for var name deduction) ---

  defp transform_block({:__block__, meta, statements}) do
    {:__block__, meta, Enum.map(statements, &transform_statement/1)}
  end

  defp transform_block(single_statement) do
    transform_statement(single_statement)
  end

  # x = var(opts) => x = var("x", opts) — auto-deduce name from LHS
  defp transform_statement({:=, meta, [{lhs_name, _, ctx} = lhs, {:var, var_meta, [opts]}]})
       when is_atom(lhs_name) and is_atom(ctx) and is_list(opts) do
    name = deduce_var_name(lhs_name, opts)
    {:=, meta, [lhs, {:var, var_meta, [name, opts]}]}
  end

  # x = var() => x = var("x") — no opts at all
  defp transform_statement({:=, meta, [{lhs_name, _, ctx} = lhs, {:var, var_meta, []}]})
       when is_atom(lhs_name) and is_atom(ctx) do
    {:=, meta, [lhs, {:var, var_meta, [Atom.to_string(lhs_name)]}]}
  end

  defp transform_statement(other), do: other

  defp deduce_var_name(lhs_name, opts) do
    case Keyword.fetch(opts, :name) do
      {:ok, explicit_name} -> explicit_name
      :error -> Atom.to_string(lhs_name)
    end
  end
end
