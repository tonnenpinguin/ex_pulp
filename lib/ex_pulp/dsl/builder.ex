defmodule ExPulp.DSL.Builder do
  @moduledoc false

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
    %{builder | constraints: [{name, constraint} | builder.constraints]}
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

    builder.constraints
    |> Enum.reverse()
    |> Enum.reduce(problem, fn {name, constraint}, prob ->
      Problem.add_constraint(prob, constraint, name)
    end)
  end
end
