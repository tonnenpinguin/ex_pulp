defmodule ExPulp.Expression do
  @moduledoc """
  A linear affine expression: a weighted sum of variables plus a constant.

  Represented as `c1*v1 + c2*v2 + ... + constant` where the `terms` map
  stores `%Variable{} => coefficient`.

  ## Expression algebra

  Expressions support a full set of linear algebra operations: addition,
  subtraction, scalar multiplication, division, and negation. These operations
  accept expressions, variables, and plain numbers, wrapping them as needed.

  Non-linear operations (multiplying two expressions that both contain
  variables) will raise an `ArgumentError`.

  ## Examples

      iex> x = ExPulp.Variable.new("x")
      iex> y = ExPulp.Variable.new("y")
      iex> expr = ExPulp.Expression.new([{x, 2}, {y, 3}], 1.0)
      iex> ExPulp.Expression.to_string(expr)
      "2*x + 3*y + 1"

  Expressions can be combined using the arithmetic functions:

      iex> x = ExPulp.Variable.new("x")
      iex> y = ExPulp.Variable.new("y")
      iex> sum = ExPulp.Expression.add(ExPulp.Expression.from_variable(x), ExPulp.Expression.from_variable(y))
      iex> ExPulp.Expression.to_string(sum)
      "x + y"

  ## Inspection

  Expressions have a human-readable inspect format:

      iex> x = ExPulp.Variable.new("x")
      iex> ExPulp.Expression.new([{x, 3}], 2)
      #Expression<3*x + 2>
  """

  alias ExPulp.Variable

  @type t :: %__MODULE__{
          terms: %{Variable.t() => number()},
          constant: number()
        }

  defstruct terms: %{}, constant: 0.0

  @doc """
  Creates an expression from a list of `{variable, coefficient}` pairs
  and an optional constant. Duplicate variables have their coefficients summed.
  Zero-coefficient terms are dropped.

  The constant is converted to a float via division by 1.

  ## Examples

      iex> x = ExPulp.Variable.new("x")
      iex> y = ExPulp.Variable.new("y")
      iex> expr = ExPulp.Expression.new([{x, 2}, {y, 3}], 1.0)
      iex> ExPulp.Expression.to_string(expr)
      "2*x + 3*y + 1"

  An empty expression defaults to zero:

      iex> ExPulp.Expression.to_string(ExPulp.Expression.new())
      "0"

  A constant-only expression:

      iex> ExPulp.Expression.to_string(ExPulp.Expression.new([], 42))
      "42"

  Duplicate variables have their coefficients summed:

      iex> x = ExPulp.Variable.new("x")
      iex> ExPulp.Expression.to_string(ExPulp.Expression.new([{x, 2}, {x, 3}]))
      "5*x"

  Variables that cancel to zero are dropped:

      iex> x = ExPulp.Variable.new("x")
      iex> expr = ExPulp.Expression.new([{x, 2}, {x, -2}])
      iex> map_size(expr.terms)
      0
  """
  @spec new([{Variable.t(), number()}], number()) :: t()
  def new(term_list \\ [], constant \\ 0.0) do
    terms =
      term_list
      |> Enum.reduce(%{}, fn {%Variable{} = var, coeff}, acc ->
        Map.update(acc, var, coeff, &Kernel.+(&1, coeff))
      end)
      |> Enum.reject(fn {_var, coeff} -> coeff == 0 end)
      |> Map.new()

    %__MODULE__{terms: terms, constant: constant / 1}
  end

  @doc """
  Creates an expression from a single variable with coefficient 1.

  ## Examples

      iex> x = ExPulp.Variable.new("x")
      iex> ExPulp.Expression.to_string(ExPulp.Expression.from_variable(x))
      "x"
  """
  @spec from_variable(Variable.t()) :: t()
  def from_variable(%Variable{} = var), do: %__MODULE__{terms: %{var => 1}}

  @doc """
  Creates an expression from a single variable with the given coefficient.

  A zero coefficient produces an empty expression (no terms).

  ## Examples

      iex> x = ExPulp.Variable.new("x")
      iex> ExPulp.Expression.to_string(ExPulp.Expression.from_variable(x, 3))
      "3*x"

      iex> x = ExPulp.Variable.new("x")
      iex> expr = ExPulp.Expression.from_variable(x, 0)
      iex> map_size(expr.terms)
      0
  """
  @spec from_variable(Variable.t(), number()) :: t()
  def from_variable(%Variable{} = var, coeff) when is_number(coeff) do
    if coeff == 0, do: %__MODULE__{}, else: %__MODULE__{terms: %{var => coeff}}
  end

  @doc """
  Wraps a value into an expression if it isn't one already.

  Accepts an `%Expression{}`, a `%Variable{}`, or a plain number. Expressions
  are returned as-is; variables become single-term expressions with coefficient
  1; numbers become constant-only expressions.

  ## Examples

      iex> x = ExPulp.Variable.new("x")
      iex> ExPulp.Expression.to_string(ExPulp.Expression.wrap(x))
      "x"

      iex> ExPulp.Expression.to_string(ExPulp.Expression.wrap(5))
      "5"

      iex> x = ExPulp.Variable.new("x")
      iex> expr = ExPulp.Expression.from_variable(x)
      iex> ExPulp.Expression.wrap(expr) == expr
      true
  """
  @spec wrap(t() | Variable.t() | number()) :: t()
  def wrap(%__MODULE__{} = expr), do: expr
  def wrap(%Variable{} = var), do: from_variable(var)
  def wrap(n) when is_number(n), do: %__MODULE__{constant: n / 1}

  @doc """
  Adds two expressions (or variables/numbers) together.

  Both operands are wrapped via `wrap/1` before addition.

  ## Examples

      iex> x = ExPulp.Variable.new("x")
      iex> y = ExPulp.Variable.new("y")
      iex> ExPulp.Expression.to_string(ExPulp.Expression.add(ExPulp.Expression.from_variable(x), ExPulp.Expression.from_variable(y)))
      "x + y"

  Adding a number to an expression:

      iex> x = ExPulp.Variable.new("x")
      iex> ExPulp.Expression.to_string(ExPulp.Expression.add(ExPulp.Expression.from_variable(x), 5))
      "x + 5"

  Adding two numbers:

      iex> ExPulp.Expression.to_string(ExPulp.Expression.add(3, 4))
      "7"
  """
  @spec add(t() | Variable.t() | number(), t() | Variable.t() | number()) :: t()
  def add(a, b) do
    a = wrap(a)
    b = wrap(b)

    terms =
      Map.merge(a.terms, b.terms, fn _var, c1, c2 -> Kernel.+(c1, c2) end)
      |> Enum.reject(fn {_var, coeff} -> coeff == 0 end)
      |> Map.new()

    %__MODULE__{terms: terms, constant: Kernel.+(a.constant, b.constant)}
  end

  @doc """
  Subtracts the second expression from the first.

  Equivalent to `add(a, negate(b))`.

  ## Examples

      iex> x = ExPulp.Variable.new("x")
      iex> y = ExPulp.Variable.new("y")
      iex> ExPulp.Expression.to_string(ExPulp.Expression.subtract(ExPulp.Expression.from_variable(x), ExPulp.Expression.from_variable(y)))
      "x - y"

  Subtracting a number:

      iex> x = ExPulp.Variable.new("x")
      iex> ExPulp.Expression.to_string(ExPulp.Expression.subtract(ExPulp.Expression.from_variable(x), 3))
      "x - 3"
  """
  @spec subtract(t() | Variable.t() | number(), t() | Variable.t() | number()) :: t()
  def subtract(a, b), do: add(a, negate(wrap(b)))

  @doc """
  Multiplies an expression by a scalar, or a scalar by an expression/variable.

  Raises `ArgumentError` if both operands contain variables (non-linear).
  When one operand is a constant-only expression, it is treated as a scalar.

  ## Examples

  Scalar times variable:

      iex> x = ExPulp.Variable.new("x")
      iex> ExPulp.Expression.to_string(ExPulp.Expression.multiply(3, x))
      "3*x"

  Variable times scalar:

      iex> x = ExPulp.Variable.new("x")
      iex> ExPulp.Expression.to_string(ExPulp.Expression.multiply(x, 3))
      "3*x"

  Scalar times expression:

      iex> x = ExPulp.Variable.new("x")
      iex> expr = ExPulp.Expression.new([{x, 2}], 1)
      iex> ExPulp.Expression.to_string(ExPulp.Expression.multiply(3, expr))
      "6*x + 3"

  Two numbers:

      iex> ExPulp.Expression.to_string(ExPulp.Expression.multiply(3, 4))
      "12"

  Constant-only expression times an expression with variables:

      iex> x = ExPulp.Variable.new("x")
      iex> const = ExPulp.Expression.new([], 3)
      iex> expr = ExPulp.Expression.new([{x, 2}], 1)
      iex> ExPulp.Expression.to_string(ExPulp.Expression.multiply(const, expr))
      "6*x + 3"

  Non-linear multiplication raises:

      iex> x = ExPulp.Variable.new("x")
      iex> y = ExPulp.Variable.new("y")
      iex> ExPulp.Expression.multiply(ExPulp.Expression.from_variable(x), ExPulp.Expression.from_variable(y))
      ** (ArgumentError) cannot multiply two non-constant expressions (non-linear)
  """
  @spec multiply(t() | Variable.t() | number(), t() | Variable.t() | number()) :: t()
  def multiply(a, b) when is_number(a) and is_number(b), do: wrap(Kernel.*(a, b))

  def multiply(n, %Variable{} = var) when is_number(n), do: from_variable(var, n)
  def multiply(%Variable{} = var, n) when is_number(n), do: from_variable(var, n)

  def multiply(n, %__MODULE__{} = expr) when is_number(n), do: scale(expr, n)
  def multiply(%__MODULE__{} = expr, n) when is_number(n), do: scale(expr, n)

  def multiply(%__MODULE__{} = a, %__MODULE__{} = b) do
    cond do
      map_size(a.terms) == 0 -> scale(b, a.constant)
      map_size(b.terms) == 0 -> scale(a, b.constant)
      true -> raise ArgumentError, "cannot multiply two non-constant expressions (non-linear)"
    end
  end

  def multiply(%Variable{} = var, %__MODULE__{} = expr), do: multiply(from_variable(var), expr)
  def multiply(%__MODULE__{} = expr, %Variable{} = var), do: multiply(expr, from_variable(var))

  @doc """
  Divides an expression by a scalar.

  The divisor must be non-zero. Accepts expressions or variables as the
  dividend.

  ## Examples

      iex> x = ExPulp.Variable.new("x")
      iex> ExPulp.Expression.to_string(ExPulp.Expression.divide(ExPulp.Expression.from_variable(x, 4), 2))
      "2*x"

      iex> x = ExPulp.Variable.new("x")
      iex> ExPulp.Expression.to_string(ExPulp.Expression.divide(x, 2))
      "0.5*x"
  """
  @spec divide(t() | Variable.t(), number()) :: t()
  def divide(expr, n) when is_number(n) and n != 0 do
    scale(wrap(expr), Kernel./(1, n))
  end

  @doc """
  Negates an expression (multiplies all terms and constant by -1).

  Also accepts a `%Variable{}`, which is wrapped first.

  ## Examples

      iex> x = ExPulp.Variable.new("x")
      iex> ExPulp.Expression.to_string(ExPulp.Expression.negate(ExPulp.Expression.new([{x, 2}], 3)))
      "-2*x - 3"

      iex> x = ExPulp.Variable.new("x")
      iex> ExPulp.Expression.to_string(ExPulp.Expression.negate(x))
      "-x"
  """
  @spec negate(t() | Variable.t()) :: t()
  def negate(expr), do: scale(wrap(expr), -1)

  @doc """
  Scales an expression by a scalar factor.

  Scaling by zero produces an empty expression.

  ## Examples

      iex> x = ExPulp.Variable.new("x")
      iex> ExPulp.Expression.to_string(ExPulp.Expression.scale(ExPulp.Expression.new([{x, 2}], 1), 3))
      "6*x + 3"

      iex> x = ExPulp.Variable.new("x")
      iex> ExPulp.Expression.to_string(ExPulp.Expression.scale(ExPulp.Expression.from_variable(x), 0))
      "0"
  """
  @spec scale(t(), number()) :: t()
  def scale(%__MODULE__{} = expr, factor) when is_number(factor) do
    if factor == 0 do
      %__MODULE__{}
    else
      terms = Map.new(expr.terms, fn {var, coeff} -> {var, Kernel.*(coeff, factor)} end)
      %__MODULE__{terms: terms, constant: Kernel.*(expr.constant, factor)}
    end
  end

  @doc """
  Evaluates the expression given a map of variable names to values.

  Returns `nil` if any variable in the expression has no corresponding entry
  in the values map.

  ## Examples

      iex> x = ExPulp.Variable.new("x")
      iex> y = ExPulp.Variable.new("y")
      iex> expr = ExPulp.Expression.new([{x, 2}, {y, 3}], 1.0)
      iex> ExPulp.Expression.evaluate(expr, %{"x" => 4.0, "y" => 2.0})
      15.0

  Returns `nil` when a variable is missing from the values map:

      iex> x = ExPulp.Variable.new("x")
      iex> ExPulp.Expression.evaluate(ExPulp.Expression.from_variable(x), %{"z" => 1.0})
      nil

  A constant-only expression ignores the values map:

      iex> ExPulp.Expression.evaluate(ExPulp.Expression.new([], 5.0), %{})
      5.0
  """
  @spec evaluate(t(), %{String.t() => number()}) :: float() | nil
  def evaluate(%__MODULE__{} = expr, values) when is_map(values) do
    Enum.reduce_while(expr.terms, expr.constant, fn {%Variable{name: name}, coeff}, acc ->
      case Map.fetch(values, name) do
        {:ok, val} -> {:cont, Kernel.+(acc, Kernel.*(coeff, val))}
        :error -> {:halt, nil}
      end
    end)
  end

  @doc """
  Returns the sorted list of variables in this expression (sorted by name).

  ## Examples

      iex> x = ExPulp.Variable.new("x")
      iex> y = ExPulp.Variable.new("y")
      iex> expr = ExPulp.Expression.new([{y, 1}, {x, 1}])
      iex> ExPulp.Expression.sorted_variables(expr) |> Enum.map(& &1.name)
      ["x", "y"]

      iex> ExPulp.Expression.sorted_variables(ExPulp.Expression.new())
      []
  """
  @spec sorted_variables(t()) :: [Variable.t()]
  def sorted_variables(%__MODULE__{} = expr) do
    expr.terms
    |> Map.keys()
    |> Enum.sort_by(& &1.name)
  end

  @doc """
  Returns a human-readable string representation of the expression.

  Terms are printed in alphabetical order by variable name. Coefficients of
  `1` or `-1` are omitted (showing just the variable name). Integer-valued
  floats are printed without a decimal point.

  ## Examples

      iex> x = ExPulp.Variable.new("x")
      iex> y = ExPulp.Variable.new("y")
      iex> ExPulp.Expression.to_string(ExPulp.Expression.new([{x, 2}, {y, -3}], 5.0))
      "2*x - 3*y + 5"

      iex> ExPulp.Expression.to_string(ExPulp.Expression.new())
      "0"

      iex> x = ExPulp.Variable.new("x")
      iex> ExPulp.Expression.to_string(ExPulp.Expression.from_variable(x))
      "x"

      iex> x = ExPulp.Variable.new("x")
      iex> ExPulp.Expression.to_string(ExPulp.Expression.negate(x))
      "-x"
  """
  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{} = expr) do
    vars = sorted_variables(expr)

    terms_str =
      vars
      |> Enum.with_index()
      |> Enum.map(fn {var, idx} ->
        coeff = Map.fetch!(expr.terms, var)
        format_term(coeff, var.name, idx == 0)
      end)
      |> Enum.join("")

    constant_str = format_constant(expr.constant, terms_str == "")

    result = terms_str <> constant_str

    if result == "", do: "0", else: result
  end

  defp format_term(coeff, name, first?) do
    abs_coeff = abs(coeff)

    coeff_str =
      cond do
        abs_coeff == 1 -> name
        abs_coeff == trunc(abs_coeff) -> "#{trunc(abs_coeff)}*#{name}"
        true -> "#{abs_coeff}*#{name}"
      end

    cond do
      coeff > 0 && first? -> coeff_str
      coeff > 0 -> " + #{coeff_str}"
      coeff < 0 && first? -> "-#{coeff_str}"
      coeff < 0 -> " - #{coeff_str}"
      true -> ""
    end
  end

  defp format_constant(c, empty?) when c == 0 do
    if empty?, do: "0", else: ""
  end

  defp format_constant(c, true) do
    format_number(c)
  end

  defp format_constant(c, false) when c > 0, do: " + #{format_number(c)}"
  defp format_constant(c, false), do: " - #{format_number(abs(c))}"

  defp format_number(n) when is_float(n) and n == trunc(n), do: "#{trunc(n)}"
  defp format_number(n), do: "#{n}"
end

defimpl String.Chars, for: ExPulp.Expression do
  def to_string(expr), do: ExPulp.Expression.to_string(expr)
end

defimpl Inspect, for: ExPulp.Expression do
  def inspect(expr, _opts) do
    "#Expression<#{ExPulp.Expression.to_string(expr)}>"
  end
end
