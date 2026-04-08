defmodule ExPulp.Result do
  @moduledoc """
  The result of solving a linear programming problem.

  A `%Result{}` struct is returned by `ExPulp.solve/2` and contains the
  solution status, the optimal objective value, and the values of all
  decision variables.

  ## Statuses

    * `:optimal` - an optimal solution was found
    * `:feasible` - a feasible solution was found but optimality was not proven
      (e.g., solver hit a time limit with an incumbent solution)
    * `:infeasible` - no feasible solution exists
    * `:unbounded` - the objective is unbounded
    * `:not_solved` - the problem has not been solved yet

  ## Typical Usage

      {:ok, result} = ExPulp.solve(problem)

      if ExPulp.Result.optimal?(result) do
        IO.puts("Objective: \#{result.objective}")
        IO.puts("x = \#{ExPulp.Result.get_variable(result, "x")}")
      end

  ## Working with Pre-built Results

  You can construct result structs directly for testing or inspection:

      result = %ExPulp.Result{
        status: :optimal,
        objective: 42.0,
        variables: %{"x" => 10.0, "y" => 32.0}
      }

      ExPulp.Result.optimal?(result)   #=> true
      ExPulp.Result.num_variables(result) #=> 2
  """

  @type status :: :optimal | :feasible | :infeasible | :unbounded | :not_solved

  @type t :: %__MODULE__{
          status: status(),
          objective: float() | nil,
          variables: %{String.t() => float()}
        }

  defstruct status: :not_solved, objective: nil, variables: %{}

  @doc """
  Returns true if the solution is optimal.

  ## Examples

      iex> ExPulp.Result.optimal?(%ExPulp.Result{status: :optimal, objective: 5.0, variables: %{}})
      true

      iex> ExPulp.Result.optimal?(%ExPulp.Result{status: :infeasible})
      false

      iex> ExPulp.Result.optimal?(%ExPulp.Result{status: :not_solved})
      false
  """
  @spec optimal?(t()) :: boolean()
  def optimal?(%__MODULE__{status: :optimal}), do: true
  def optimal?(%__MODULE__{}), do: false

  @doc """
  Returns true if a feasible solution was found (both `:optimal` and `:feasible`
  count as feasible).

  ## Examples

      iex> ExPulp.Result.feasible?(%ExPulp.Result{status: :optimal, objective: 5.0, variables: %{}})
      true

      iex> ExPulp.Result.feasible?(%ExPulp.Result{status: :feasible, objective: 5.0, variables: %{}})
      true

      iex> ExPulp.Result.feasible?(%ExPulp.Result{status: :infeasible})
      false

      iex> ExPulp.Result.feasible?(%ExPulp.Result{status: :not_solved})
      false
  """
  @spec feasible?(t()) :: boolean()
  def feasible?(%__MODULE__{status: :optimal}), do: true
  def feasible?(%__MODULE__{status: :feasible}), do: true
  def feasible?(%__MODULE__{}), do: false

  @doc """
  Returns true if the problem was found to be infeasible.

  ## Examples

      iex> ExPulp.Result.infeasible?(%ExPulp.Result{status: :infeasible})
      true

      iex> ExPulp.Result.infeasible?(%ExPulp.Result{status: :optimal, objective: 5.0, variables: %{}})
      false
  """
  @spec infeasible?(t()) :: boolean()
  def infeasible?(%__MODULE__{status: :infeasible}), do: true
  def infeasible?(%__MODULE__{}), do: false

  @doc """
  Returns true if the problem was found to be unbounded.

  ## Examples

      iex> ExPulp.Result.unbounded?(%ExPulp.Result{status: :unbounded})
      true

      iex> ExPulp.Result.unbounded?(%ExPulp.Result{status: :optimal, objective: 5.0, variables: %{}})
      false
  """
  @spec unbounded?(t()) :: boolean()
  def unbounded?(%__MODULE__{status: :unbounded}), do: true
  def unbounded?(%__MODULE__{}), do: false

  @doc """
  Gets the value of a variable from the result.
  Accepts a variable name string or a `%Variable{}` struct.

  Returns `nil` if the variable is not present in the solution.

  ## Examples

      iex> result = %ExPulp.Result{status: :optimal, objective: 5.0, variables: %{"x" => 3.0, "y" => 2.0}}
      iex> ExPulp.Result.get_variable(result, "x")
      3.0

      iex> result = %ExPulp.Result{status: :optimal, objective: 5.0, variables: %{"x" => 3.0}}
      iex> ExPulp.Result.get_variable(result, "z")
      nil

      iex> result = %ExPulp.Result{status: :optimal, objective: 5.0, variables: %{"x" => 3.0}}
      iex> x = ExPulp.Variable.new("x")
      iex> ExPulp.Result.get_variable(result, x)
      3.0
  """
  @spec get_variable(t(), String.t() | ExPulp.Variable.t()) :: float() | nil
  def get_variable(%__MODULE__{} = result, %ExPulp.Variable{name: name}) do
    Map.get(result.variables, name)
  end

  def get_variable(%__MODULE__{} = result, name) when is_binary(name) do
    Map.get(result.variables, name)
  end

  @doc """
  Returns the number of variables in the solution.

  ## Examples

      iex> result = %ExPulp.Result{status: :optimal, variables: %{"x" => 1.0, "y" => 2.0, "z" => 3.0}}
      iex> ExPulp.Result.num_variables(result)
      3

      iex> ExPulp.Result.num_variables(%ExPulp.Result{})
      0
  """
  @spec num_variables(t()) :: non_neg_integer()
  def num_variables(%__MODULE__{} = result), do: map_size(result.variables)

  @doc """
  Evaluates an expression using the solution's variable values.
  Returns `nil` if any variable in the expression has no solution value.

  Accepts an `%Expression{}` or a `%Variable{}` (which is wrapped into
  an expression automatically).

  ## Examples

      iex> x = ExPulp.Variable.new("x")
      iex> expr = ExPulp.Expression.from_variable(x, 2)
      iex> result = %ExPulp.Result{status: :optimal, variables: %{"x" => 4.0}}
      iex> ExPulp.Result.evaluate(result, expr)
      8.0

      iex> x = ExPulp.Variable.new("x")
      iex> result = %ExPulp.Result{status: :optimal, variables: %{"x" => 7.0}}
      iex> ExPulp.Result.evaluate(result, x)
      7.0

      iex> x = ExPulp.Variable.new("x")
      iex> result = %ExPulp.Result{status: :optimal, variables: %{}}
      iex> ExPulp.Result.evaluate(result, x)
      nil
  """
  @spec evaluate(t(), ExPulp.Expression.t() | ExPulp.Variable.t()) :: float() | nil
  def evaluate(%__MODULE__{} = result, expr) do
    ExPulp.Expression.evaluate(ExPulp.Expression.wrap(expr), result.variables)
  end
end

defimpl Inspect, for: ExPulp.Result do
  def inspect(%ExPulp.Result{} = r, _opts) do
    obj =
      if r.objective,
        do: ", objective: #{r.objective}",
        else: ""

    vars = map_size(r.variables)

    "#Result<#{r.status}#{obj}, #{vars} variables>"
  end
end
