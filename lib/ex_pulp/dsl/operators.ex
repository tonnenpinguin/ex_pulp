defmodule ExPulp.DSL.Operators do
  @moduledoc """
  Overridden arithmetic and comparison operators for the ExPulp DSL.

  These operators are automatically imported inside `ExPulp.model/3` blocks,
  replacing Kernel's versions. You should never need to import this module
  directly.

  ## Dispatch rules

  - **Both operands are numbers** — delegates to `Kernel` (normal arithmetic)
  - **Any operand is a `Variable` or `Expression`** — produces an `Expression`
  - **Comparison with a `Variable`/`Expression`** — produces a `Constraint`

  ## Overridden operators

  | Operator | Number + Number | Variable/Expression involved |
  |----------|----------------|-----------------------------|
  | `a + b`  | `Kernel.+(a, b)` | `Expression.add(a, b)` |
  | `a - b`  | `Kernel.-(a, b)` | `Expression.subtract(a, b)` |
  | `a * b`  | `Kernel.*(a, b)` | `Expression.multiply(a, b)` |
  | `a / b`  | `Kernel./(a, b)` | `Expression.divide(a, b)` |
  | `-a`     | `Kernel.-(a)` | `Expression.negate(a)` |
  | `a >= b` | `Kernel.>=(a, b)` | `Constraint.geq(a, b)` |
  | `a <= b` | `Kernel.<=(a, b)` | `Constraint.leq(a, b)` |
  | `a == b` | `Kernel.==(a, b)` | `Constraint.eq(a, b)` |
  """

  alias ExPulp.{Variable, Expression, Constraint}

  import Kernel, except: [+: 2, -: 2, *: 2, /: 2, >=: 2, <=: 2, ==: 2, -: 1]

  # --- Addition ---

  def a + b when is_number(a) and is_number(b), do: Kernel.+(a, b)
  def a + b, do: Expression.add(a, b)

  # --- Subtraction ---

  def a - b when is_number(a) and is_number(b), do: Kernel.-(a, b)
  def a - b, do: Expression.subtract(a, b)

  # --- Unary minus ---

  def -a when is_number(a), do: Kernel.-(a)
  def -(%Variable{} = a), do: Expression.negate(Expression.from_variable(a))
  def -(%Expression{} = a), do: Expression.negate(a)

  # --- Multiplication ---

  def a * b when is_number(a) and is_number(b), do: Kernel.*(a, b)
  def a * b, do: Expression.multiply(a, b)

  # --- Division ---

  def a / b when is_number(a) and is_number(b), do: Kernel./(a, b)
  def a / b when is_number(b), do: Expression.divide(a, b)

  # --- Comparison operators (produce Constraints) ---

  def a >= b when is_number(a) and is_number(b), do: Kernel.>=(a, b)
  def a >= b, do: Constraint.geq(a, b)

  def a <= b when is_number(a) and is_number(b), do: Kernel.<=(a, b)
  def a <= b, do: Constraint.leq(a, b)

  def a == b when is_number(a) and is_number(b), do: Kernel.==(a, b)
  def a == b, do: Constraint.eq(a, b)
end
