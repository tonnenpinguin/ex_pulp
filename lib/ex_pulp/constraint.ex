defmodule ExPulp.Constraint do
  @moduledoc """
  A linear constraint: `expression sense rhs`.

  A constraint binds a linear expression to a right-hand side value using one
  of three senses: `<=` (`:leq`), `>=` (`:geq`), or `=` (`:eq`).

  For example, `x + y >= 5` is represented as
  `%Constraint{expression: expr_for_x_plus_y, sense: :geq, rhs: 5.0}`.

  ## Normalization

  When both sides contain variables, the constraint is normalized so that all
  variable terms are on the left and the RHS becomes zero:

      iex> x = ExPulp.Variable.new("x")
      iex> y = ExPulp.Variable.new("y")
      iex> c = ExPulp.Constraint.leq(ExPulp.Expression.from_variable(x), ExPulp.Expression.from_variable(y))
      iex> ExPulp.Constraint.to_string(c)
      "x - y <= 0"

  When the left side is a plain number, the constraint is flipped so that the
  expression remains on the left:

      iex> x = ExPulp.Variable.new("x")
      iex> c = ExPulp.Constraint.leq(5, ExPulp.Expression.from_variable(x))
      iex> ExPulp.Constraint.to_string(c)
      "-x >= -5"

  ## Effective RHS

  When an expression contains a constant term, `effective_rhs/1` subtracts it
  from the RHS, which is needed for LP file output where constants are moved
  to the right side:

      iex> x = ExPulp.Variable.new("x")
      iex> expr = ExPulp.Expression.new([{x, 1}], 3.0)
      iex> c = ExPulp.Constraint.leq(expr, 10)
      iex> ExPulp.Constraint.effective_rhs(c)
      7.0
      iex> ExPulp.Constraint.to_string(c)
      "x <= 7"

  ## Inspection

  Constraints have a human-readable inspect format:

      iex> x = ExPulp.Variable.new("x")
      iex> ExPulp.Constraint.geq(ExPulp.Expression.from_variable(x), 5)
      #Constraint<x >= 5>
  """

  alias ExPulp.{Expression, Variable}

  @type sense :: :leq | :eq | :geq

  @type t :: %__MODULE__{
          expression: Expression.t(),
          sense: sense(),
          rhs: number()
        }

  @enforce_keys [:expression, :sense, :rhs]
  defstruct [:expression, :sense, :rhs]

  @doc """
  Creates a `<=` constraint.

  ## Examples

      iex> x = ExPulp.Variable.new("x")
      iex> ExPulp.Constraint.to_string(ExPulp.Constraint.leq(ExPulp.Expression.from_variable(x), 5))
      "x <= 5"

      iex> x = ExPulp.Variable.new("x")
      iex> y = ExPulp.Variable.new("y")
      iex> ExPulp.Constraint.to_string(ExPulp.Constraint.leq(ExPulp.Expression.from_variable(x), ExPulp.Expression.from_variable(y)))
      "x - y <= 0"
  """
  @spec leq(Expression.t() | Variable.t(), number() | Expression.t() | Variable.t()) :: t()
  def leq(left, right), do: make_constraint(left, :leq, right)

  @doc """
  Creates a `>=` constraint.

  ## Examples

      iex> x = ExPulp.Variable.new("x")
      iex> y = ExPulp.Variable.new("y")
      iex> expr = ExPulp.Expression.new([{x, 1}, {y, 1}])
      iex> ExPulp.Constraint.to_string(ExPulp.Constraint.geq(expr, 10))
      "x + y >= 10"
  """
  @spec geq(Expression.t() | Variable.t(), number() | Expression.t() | Variable.t()) :: t()
  def geq(left, right), do: make_constraint(left, :geq, right)

  @doc """
  Creates an `=` constraint (equality).

  ## Examples

      iex> x = ExPulp.Variable.new("x")
      iex> ExPulp.Constraint.to_string(ExPulp.Constraint.eq(ExPulp.Expression.from_variable(x), 3))
      "x = 3"
  """
  @spec eq(Expression.t() | Variable.t(), number() | Expression.t() | Variable.t()) :: t()
  def eq(left, right), do: make_constraint(left, :eq, right)

  defp make_constraint(left, sense, right) when is_number(right) do
    %__MODULE__{expression: Expression.wrap(left), sense: sense, rhs: right / 1}
  end

  defp make_constraint(left, sense, right) when is_number(left) do
    # Flip: number sense expr  =>  -expr flipped_sense number
    flipped =
      case sense do
        :leq -> :geq
        :geq -> :leq
        :eq -> :eq
      end

    %__MODULE__{
      expression: Expression.negate(Expression.wrap(right)),
      sense: flipped,
      rhs: Kernel.-(left) / 1
    }
  end

  defp make_constraint(left, sense, right) do
    # expr sense expr  =>  (left - right) sense 0
    expr = Expression.subtract(Expression.wrap(left), Expression.wrap(right))
    %__MODULE__{expression: expr, sense: sense, rhs: 0.0}
  end

  @doc """
  Returns the effective RHS for LP file output.

  Accounts for any constant term in the expression by computing
  `rhs - expression.constant`. This is needed because LP format requires all
  constants on the right-hand side.

  ## Examples

      iex> x = ExPulp.Variable.new("x")
      iex> c = ExPulp.Constraint.leq(ExPulp.Expression.from_variable(x), 5)
      iex> ExPulp.Constraint.effective_rhs(c)
      5.0

      iex> x = ExPulp.Variable.new("x")
      iex> expr = ExPulp.Expression.new([{x, 1}], 3.0)
      iex> c = ExPulp.Constraint.leq(expr, 10)
      iex> ExPulp.Constraint.effective_rhs(c)
      7.0
  """
  @spec effective_rhs(t()) :: float()
  def effective_rhs(%__MODULE__{} = c) do
    Kernel.-(c.rhs, c.expression.constant) / 1
  end

  @doc """
  Returns the sense as an LP format string.

  ## Examples

      iex> ExPulp.Constraint.sense_string(:leq)
      "<="

      iex> ExPulp.Constraint.sense_string(:geq)
      ">="

      iex> ExPulp.Constraint.sense_string(:eq)
      "="
  """
  @spec sense_string(sense()) :: String.t()
  def sense_string(:leq), do: "<="
  def sense_string(:geq), do: ">="
  def sense_string(:eq), do: "="

  @doc """
  Returns a human-readable string representation of the constraint.

  The expression constant is folded into the RHS. Terms are printed in
  alphabetical order by variable name.

  ## Examples

      iex> x = ExPulp.Variable.new("x")
      iex> ExPulp.Constraint.to_string(ExPulp.Constraint.leq(ExPulp.Expression.from_variable(x), 5))
      "x <= 5"

      iex> x = ExPulp.Variable.new("x")
      iex> y = ExPulp.Variable.new("y")
      iex> expr = ExPulp.Expression.new([{x, 1}, {y, 1}])
      iex> ExPulp.Constraint.to_string(ExPulp.Constraint.geq(expr, 10))
      "x + y >= 10"

      iex> x = ExPulp.Variable.new("x")
      iex> expr = ExPulp.Expression.new([{x, 1}], 3.0)
      iex> ExPulp.Constraint.to_string(ExPulp.Constraint.leq(expr, 10))
      "x <= 7"
  """
  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{} = c) do
    expr_str = Expression.to_string(%{c.expression | constant: 0.0})
    rhs = effective_rhs(c)

    rhs_str =
      if is_float(rhs) and rhs == trunc(rhs),
        do: "#{trunc(rhs)}",
        else: "#{rhs}"

    "#{expr_str} #{sense_string(c.sense)} #{rhs_str}"
  end
end

defimpl String.Chars, for: ExPulp.Constraint do
  def to_string(constraint), do: ExPulp.Constraint.to_string(constraint)
end

defimpl Inspect, for: ExPulp.Constraint do
  def inspect(constraint, _opts) do
    "#Constraint<#{ExPulp.Constraint.to_string(constraint)}>"
  end
end
