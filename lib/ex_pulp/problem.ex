defmodule ExPulp.Problem do
  @moduledoc """
  A linear programming problem: objective, constraints, and variables.

  A `%Problem{}` struct holds the objective function, constraints, registered
  variables, and metadata needed to write the problem to an LP file and solve it.

  ## Building a Problem

  Problems are typically built with the pipe operator:

      alias ExPulp.{Variable, Expression, Constraint, Problem}

      x = Variable.new("x", low: 0, high: 10)
      y = Variable.new("y", low: 0, high: 10)

      problem =
        Problem.new("diet", :minimize)
        |> Problem.set_objective(Expression.new([{x, 1}, {y, 1}]))
        |> Problem.add_constraint(
             Constraint.geq(Expression.new([{x, 1}, {y, 1}]), 5),
             "sum_ge_5"
           )

  Variables referenced in the objective or constraints are automatically
  registered with the problem. You can also register them explicitly
  with `add_variable/2`.

  ## Validation

  Before solving, call `validate/1` to check that:
    * An objective function is set
    * No duplicate constraint names exist
    * All referenced variables are registered

  ## Query API

  Use `num_variables/1`, `num_constraints/1`, `mip?/1`, `has_constraint?/2`,
  and `constraint_names/1` to inspect a problem's structure.
  """

  alias ExPulp.{Variable, Expression, Constraint}

  @type sense :: :minimize | :maximize

  @type t :: %__MODULE__{
          name: String.t(),
          sense: sense(),
          objective: Expression.t() | nil,
          constraints: [{String.t(), Constraint.t()}],
          variables: %{String.t() => Variable.t()},
          last_constraint_id: non_neg_integer()
        }

  defstruct name: "problem",
            sense: :minimize,
            objective: nil,
            constraints: [],
            variables: %{},
            last_constraint_id: 0

  @doc """
  Creates a new problem with the given name and optimization sense.

  Spaces in the name are replaced with underscores to produce valid LP file names.

  ## Examples

      iex> problem = ExPulp.Problem.new("my problem")
      iex> problem.name
      "my_problem"

      iex> problem = ExPulp.Problem.new("test", :maximize)
      iex> problem.sense
      :maximize

      iex> problem = ExPulp.Problem.new("test")
      iex> problem.sense
      :minimize
  """
  @spec new(String.t(), sense()) :: t()
  def new(name, sense \\ :minimize) when sense in [:minimize, :maximize] do
    sanitized = String.replace(name, " ", "_")
    %__MODULE__{name: sanitized, sense: sense}
  end

  @doc """
  Registers a variable with the problem.

  If a variable with the same name is already registered, it is not replaced.

  ## Examples

      iex> alias ExPulp.{Variable, Problem}
      iex> x = Variable.new("x", low: 0)
      iex> problem = Problem.new("test") |> Problem.add_variable(x)
      iex> Problem.num_variables(problem)
      1
  """
  @spec add_variable(t(), Variable.t()) :: t()
  def add_variable(%__MODULE__{} = problem, %Variable{} = var) do
    %{problem | variables: Map.put_new(problem.variables, var.name, var)}
  end

  @doc """
  Registers multiple variables with the problem.
  """
  @spec add_variables(t(), [Variable.t()]) :: t()
  def add_variables(%__MODULE__{} = problem, vars) when is_list(vars) do
    Enum.reduce(vars, problem, &add_variable(&2, &1))
  end

  @doc """
  Sets the objective function and registers any new variables.

  Accepts an `%Expression{}` or a `%Variable{}` (which is wrapped into
  a single-term expression).

  ## Examples

      iex> alias ExPulp.{Variable, Expression, Problem}
      iex> x = Variable.new("x", low: 0)
      iex> problem = Problem.new("test") |> Problem.set_objective(Expression.from_variable(x))
      iex> Problem.num_variables(problem)
      1
  """
  @spec set_objective(t(), Expression.t() | Variable.t()) :: t()
  def set_objective(%__MODULE__{} = problem, expr) do
    expr = Expression.wrap(expr)
    problem = register_expression_variables(problem, expr)
    %{problem | objective: expr}
  end

  @doc """
  Adds a constraint to the problem and registers any new variables.
  If no name is given, one is auto-generated (e.g., `"_C1"`, `"_C2"`, ...).

  ## Examples

      iex> alias ExPulp.{Variable, Expression, Constraint, Problem}
      iex> x = Variable.new("x", low: 0)
      iex> problem = Problem.new("test")
      ...>   |> Problem.set_objective(Expression.from_variable(x))
      ...>   |> Problem.add_constraint(Constraint.geq(Expression.from_variable(x), 5), "x_lb")
      iex> Problem.num_constraints(problem)
      1

      iex> alias ExPulp.{Variable, Expression, Constraint, Problem}
      iex> x = Variable.new("x", low: 0)
      iex> problem = Problem.new("test")
      ...>   |> Problem.set_objective(Expression.from_variable(x))
      ...>   |> Problem.add_constraint(Constraint.geq(Expression.from_variable(x), 5))
      iex> Problem.constraint_names(problem)
      ["_C1"]
  """
  @spec add_constraint(t(), Constraint.t(), String.t() | nil) :: t()
  def add_constraint(%__MODULE__{} = problem, %Constraint{} = constraint, name \\ nil) do
    {name, problem} =
      case name do
        nil ->
          id = problem.last_constraint_id + 1
          {"_C#{id}", %{problem | last_constraint_id: id}}

        name ->
          {name, problem}
      end

    problem = register_expression_variables(problem, constraint.expression)
    %{problem | constraints: problem.constraints ++ [{name, constraint}]}
  end

  # --- Query API ---

  @doc """
  Returns the sorted list of all variables in the problem.
  """
  @spec variables_sorted(t()) :: [Variable.t()]
  def variables_sorted(%__MODULE__{} = problem) do
    problem.variables
    |> Map.values()
    |> Enum.sort_by(& &1.name)
  end

  @doc """
  Returns true if the problem has any integer or binary variables.

  ## Examples

      iex> alias ExPulp.{Variable, Expression, Problem}
      iex> x = Variable.new("x", low: 0)
      iex> problem = Problem.new("test") |> Problem.set_objective(Expression.from_variable(x))
      iex> Problem.mip?(problem)
      false

      iex> alias ExPulp.{Variable, Expression, Problem}
      iex> x = Variable.new("x", low: 0, category: :integer)
      iex> problem = Problem.new("test") |> Problem.set_objective(Expression.from_variable(x))
      iex> Problem.mip?(problem)
      true

      iex> alias ExPulp.{Variable, Expression, Problem}
      iex> x = Variable.new("x", category: :binary)
      iex> problem = Problem.new("test") |> Problem.set_objective(Expression.from_variable(x))
      iex> Problem.mip?(problem)
      true
  """
  @spec mip?(t()) :: boolean()
  def mip?(%__MODULE__{} = problem) do
    Enum.any?(Map.values(problem.variables), fn v -> v.category == :integer end)
  end

  @doc "Returns true if the objective contains quadratic terms."
  @spec quadratic?(t()) :: boolean()
  def quadratic?(%__MODULE__{objective: nil}), do: false
  def quadratic?(%__MODULE__{objective: obj}), do: Expression.quadratic?(obj)

  @doc """
  Returns the number of variables in the problem.

  ## Examples

      iex> alias ExPulp.{Variable, Expression, Problem}
      iex> x = Variable.new("x", low: 0)
      iex> y = Variable.new("y", low: 0)
      iex> problem = Problem.new("test")
      ...>   |> Problem.set_objective(Expression.new([{x, 1}, {y, 1}]))
      iex> Problem.num_variables(problem)
      2
  """
  @spec num_variables(t()) :: non_neg_integer()
  def num_variables(%__MODULE__{} = problem), do: map_size(problem.variables)

  @doc """
  Returns the number of constraints in the problem.

  ## Examples

      iex> ExPulp.Problem.num_constraints(ExPulp.Problem.new("empty"))
      0
  """
  @spec num_constraints(t()) :: non_neg_integer()
  def num_constraints(%__MODULE__{} = problem), do: length(problem.constraints)

  @doc """
  Gets a constraint by name. Returns `{:ok, constraint}` or `:error`.
  """
  @spec get_constraint(t(), String.t()) :: {:ok, Constraint.t()} | :error
  def get_constraint(%__MODULE__{} = problem, name) when is_binary(name) do
    case List.keyfind(problem.constraints, name, 0) do
      {^name, constraint} -> {:ok, constraint}
      nil -> :error
    end
  end

  @doc """
  Returns true if a constraint with the given name exists.

  ## Examples

      iex> alias ExPulp.{Variable, Expression, Constraint, Problem}
      iex> x = Variable.new("x", low: 0)
      iex> problem = Problem.new("test")
      ...>   |> Problem.set_objective(Expression.from_variable(x))
      ...>   |> Problem.add_constraint(Constraint.geq(Expression.from_variable(x), 5), "x_lb")
      iex> Problem.has_constraint?(problem, "x_lb")
      true

      iex> alias ExPulp.{Variable, Expression, Constraint, Problem}
      iex> x = Variable.new("x", low: 0)
      iex> problem = Problem.new("test")
      ...>   |> Problem.set_objective(Expression.from_variable(x))
      ...>   |> Problem.add_constraint(Constraint.geq(Expression.from_variable(x), 5), "x_lb")
      iex> Problem.has_constraint?(problem, "missing")
      false
  """
  @spec has_constraint?(t(), String.t()) :: boolean()
  def has_constraint?(%__MODULE__{} = problem, name) when is_binary(name) do
    List.keymember?(problem.constraints, name, 0)
  end

  @doc """
  Returns the list of constraint names, in the order they were added.

  ## Examples

      iex> alias ExPulp.{Variable, Expression, Constraint, Problem}
      iex> x = Variable.new("x", low: 0)
      iex> expr = Expression.from_variable(x)
      iex> problem = Problem.new("test")
      ...>   |> Problem.set_objective(expr)
      ...>   |> Problem.add_constraint(Constraint.geq(expr, 1), "first")
      ...>   |> Problem.add_constraint(Constraint.leq(expr, 10), "second")
      iex> Problem.constraint_names(problem)
      ["first", "second"]
  """
  @spec constraint_names(t()) :: [String.t()]
  def constraint_names(%__MODULE__{} = problem) do
    Enum.map(problem.constraints, fn {name, _} -> name end)
  end

  # --- Validation ---

  @doc """
  Validates the problem, returning `{:ok, problem}` or `{:error, reasons}`.

  Checks:
    * Objective is set
    * No duplicate constraint names
    * All variables referenced in expressions are registered

  ## Examples

      iex> alias ExPulp.{Variable, Expression, Problem}
      iex> x = Variable.new("x", low: 0)
      iex> problem = Problem.new("test") |> Problem.set_objective(Expression.from_variable(x))
      iex> {:ok, _} = Problem.validate(problem)

      iex> {:error, reasons} = ExPulp.Problem.validate(ExPulp.Problem.new("empty"))
      iex> reasons
      ["no objective function set"]
  """
  @spec validate(t()) :: {:ok, t()} | {:error, [String.t()]}
  def validate(%__MODULE__{} = problem) do
    errors =
      []
      |> check_objective(problem)
      |> check_duplicate_constraints(problem)
      |> check_variables_registered(problem)

    case errors do
      [] -> {:ok, problem}
      errors -> {:error, Enum.reverse(errors)}
    end
  end

  defp check_objective(errors, %__MODULE__{objective: nil}),
    do: ["no objective function set" | errors]

  defp check_objective(errors, _problem), do: errors

  defp check_duplicate_constraints(errors, %__MODULE__{constraints: constraints}) do
    names = Enum.map(constraints, fn {name, _} -> name end)
    dupes = names -- Enum.uniq(names)

    case Enum.uniq(dupes) do
      [] -> errors
      dupes -> ["duplicate constraint names: #{Enum.join(dupes, ", ")}" | errors]
    end
  end

  defp check_variables_registered(errors, %__MODULE__{} = problem) do
    registered = MapSet.new(Map.keys(problem.variables))

    all_referenced =
      collect_variable_names(problem.objective) ++
        Enum.flat_map(problem.constraints, fn {_, c} ->
          collect_variable_names(c.expression)
        end)

    missing =
      all_referenced
      |> MapSet.new()
      |> MapSet.difference(registered)
      |> MapSet.to_list()

    case missing do
      [] -> errors
      names -> ["unregistered variables: #{Enum.join(names, ", ")}" | errors]
    end
  end

  defp collect_variable_names(nil), do: []

  defp collect_variable_names(%Expression{} = expr) do
    Enum.map(expr.terms, fn {%Variable{name: name}, _} -> name end)
  end

  defp register_expression_variables(problem, %Expression{} = expr) do
    Enum.reduce(expr.terms, problem, fn {%Variable{} = var, _coeff}, prob ->
      add_variable(prob, var)
    end)
  end
end

defimpl Inspect, for: ExPulp.Problem do
  def inspect(%ExPulp.Problem{} = p, _opts) do
    type = if ExPulp.Problem.mip?(p), do: "MIP", else: "LP"

    "#Problem<\"#{p.name}\" #{p.sense} #{type}, " <>
      "#{ExPulp.Problem.num_variables(p)} vars, " <>
      "#{ExPulp.Problem.num_constraints(p)} constraints>"
  end
end
