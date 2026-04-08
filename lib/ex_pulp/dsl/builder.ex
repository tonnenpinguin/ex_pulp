defmodule ExPulp.DSL.Builder do
  @moduledoc """
  Accumulator used internally by the DSL macro to collect objective and
  constraints during model block evaluation.

  This module is not part of the public API. It is used by `ExPulp.DSL`
  to build up a problem definition which is then converted to a
  `%ExPulp.Problem{}` via `to_problem/1`.
  """

  alias ExPulp.{Expression, Variable, Constraint, Problem}

  @type t :: %__MODULE__{
          name: String.t(),
          sense: :minimize | :maximize,
          objective: Expression.t() | nil,
          constraints: [{String.t() | nil, Constraint.t()}],
          variables: [Variable.t()]
        }

  defstruct [:name, :sense, objective: nil, constraints: [], variables: []]

  @spec new(String.t(), :minimize | :maximize) :: t()
  def new(name, sense) when sense in [:minimize, :maximize] do
    %__MODULE__{name: name, sense: sense}
  end

  @spec set_objective(t(), Expression.t() | Variable.t()) :: t()
  def set_objective(%__MODULE__{} = builder, expr) do
    %{builder | objective: Expression.wrap(expr)}
  end

  @spec add_to_objective(t(), Expression.t() | Variable.t()) :: t()
  def add_to_objective(%__MODULE__{objective: nil} = builder, expr) do
    %{builder | objective: Expression.wrap(expr)}
  end

  def add_to_objective(%__MODULE__{} = builder, expr) do
    %{builder | objective: Expression.add(builder.objective, Expression.wrap(expr))}
  end

  @spec add_constraint(t(), Constraint.t(), String.t() | nil) :: t()
  def add_constraint(%__MODULE__{} = builder, %Constraint{} = constraint, name \\ nil) do
    %{builder | constraints: builder.constraints ++ [{name, constraint}]}
  end

  @spec to_problem(t()) :: Problem.t()
  def to_problem(%__MODULE__{} = builder) do
    problem = Problem.new(builder.name, builder.sense)

    problem =
      if builder.objective do
        Problem.set_objective(problem, builder.objective)
      else
        problem
      end

    Enum.reduce(builder.constraints, problem, fn {name, constraint}, prob ->
      Problem.add_constraint(prob, constraint, name)
    end)
  end
end
