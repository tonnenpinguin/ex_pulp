defmodule ExPulp do
  @moduledoc """
  ExPulp: Linear, mixed-integer, and quadratic programming for Elixir.

  Provides a DSL for defining optimization problems with natural arithmetic syntax,
  and solves them using external solvers (HiGHS by default, CBC also supported).

  ## Quick Start

      # 1. Define a problem using the DSL
      problem = ExPulp.model "diet", :minimize do
        x = var(low: 0, high: 10)
        y = var(low: 0, high: 10)

        minimize 2 * x + 3 * y
        subject_to "lower_bound", x + y >= 5
      end

      # 2. Solve it
      {:ok, result} = ExPulp.solve(problem)

      # 3. Read results
      result.status     #=> :optimal
      result.objective  #=> 10.0
      ExPulp.value(result, "x")  #=> 5.0

  ## Example

      problem = ExPulp.model "diet", :minimize do
        x = var(low: 0, high: 10)
        y = var(low: 0, high: 10)

        minimize 2 * x + 3 * y
        subject_to "lower_bound", x + y >= 5
      end

      {:ok, result} = ExPulp.solve(problem)
      result.status     #=> :optimal
      result.objective  #=> 10.0
      result.variables  #=> %{"x" => 5.0, "y" => 0.0}

  ## Returning variable references

  End the block with a map or tuple to pass variable references out:

      {problem, vars} = ExPulp.model "test", :minimize do
        x = var(low: 0, high: 10)
        y = var(low: 0, high: 10)
        minimize x + y
        subject_to x + y >= 5
        %{x: x, y: y}
      end

      {:ok, result} = ExPulp.solve(problem)
      Result.evaluate(result, vars.x)  #=> 0.0

  Variable names are automatically deduced from the assignment target
  (`x = var(...)` creates a variable named `"x"`). Override with an
  explicit first argument: `x = var("custom_name", low: 0)` or the
  `:name` option: `x = var(name: "custom_name", low: 0)`.

  ## Functional API

  You can also build problems without the DSL:

      alias ExPulp.{Variable, Expression, Constraint, Problem}

      x = Variable.new("x", low: 0, high: 10)
      y = Variable.new("y", low: 0, high: 10)

      problem = Problem.new("test", :minimize)
      |> Problem.set_objective(Expression.new([{x, 1}, {y, 1}]))
      |> Problem.add_constraint(
           Constraint.geq(Expression.new([{x, 1}, {y, 1}]), 5),
           "sum_ge_5"
         )

      {:ok, result} = ExPulp.solve(problem)
  """

  alias ExPulp.{Problem, Result}

  @doc """
  Defines a linear programming model using the ExPulp DSL.

  Inside the block, arithmetic operators (`+`, `-`, `*`, `/`) and comparison
  operators (`>=`, `<=`, `==`) work on variables and expressions to build
  constraints.

  Use `var/2` to create variables, `minimize`/`maximize` to set the objective,
  and `subject_to` to add constraints.

  Returns `%Problem{}` if the last expression is a DSL form, or
  `{%Problem{}, data}` if the last expression is a map or tuple.
  """
  defmacro model(name, sense, do: block) do
    quote do
      require ExPulp.DSL
      ExPulp.DSL.model(unquote(name), unquote(sense), do: unquote(block))
    end
  end

  @doc """
  Solves a problem using the specified solver.

  ## Options
    * `:solver` - solver module (default: `ExPulp.Solver.HiGHS`)
    * `:time_limit` - max time in seconds
    * `:keep_files` - if true, temp files are not deleted

  Returns `{:ok, %Result{}}` or `{:error, reason}`.
  """
  @spec solve(Problem.t(), keyword()) :: {:ok, Result.t()} | {:error, term()}
  def solve(%Problem{} = problem, opts \\ []) do
    case Problem.validate(problem) do
      {:ok, _} ->
        solver = Keyword.get(opts, :solver, ExPulp.Solver.HiGHS)
        solver.solve(problem, opts)

      {:error, reasons} ->
        {:error, {:invalid_problem, reasons}}
    end
  end

  @doc """
  Gets the value of a variable from a result.

  Accepts a variable name string or a `%Variable{}` struct.
  Returns `nil` if the variable is not present in the solution.

  ## Examples

      iex> result = %ExPulp.Result{status: :optimal, objective: 5.0, variables: %{"x" => 3.0, "y" => 2.0}}
      iex> ExPulp.value(result, "x")
      3.0

      iex> result = %ExPulp.Result{status: :optimal, objective: 5.0, variables: %{"x" => 3.0}}
      iex> ExPulp.value(result, "missing")
      nil

      iex> result = %ExPulp.Result{status: :optimal, objective: 5.0, variables: %{"x" => 3.0}}
      iex> x = ExPulp.Variable.new("x")
      iex> ExPulp.value(result, x)
      3.0
  """
  @spec value(Result.t(), ExPulp.Variable.t() | String.t()) :: float() | nil
  defdelegate value(result, var_or_name), to: Result, as: :get_variable
end
