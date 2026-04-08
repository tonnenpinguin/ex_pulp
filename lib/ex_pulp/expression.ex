defmodule ExPulp.Expression do
  @moduledoc """
  A linear or quadratic affine expression.

  A linear expression is `c1*v1 + c2*v2 + ... + constant`.
  A quadratic expression additionally contains terms like `c*v1*v2` or `c*v^2`.

  The `terms` map stores linear coefficients (`%Variable{} => number`),
  and `quad_terms` stores quadratic coefficients (`{%Variable{}, %Variable{}} => number`).
  Quadratic keys are canonically ordered by variable name.

  ## Quadratic expressions

  Multiplying two expressions that contain variables produces quadratic terms:

      iex> x = ExPulp.Variable.new("x")
      iex> y = ExPulp.Variable.new("y")
      iex> expr = ExPulp.Expression.multiply(ExPulp.Expression.from_variable(x), ExPulp.Expression.from_variable(y))
      iex> ExPulp.Expression.to_string(expr)
      "x*y"

  Quadratic objectives are supported by HiGHS. CBC supports linear objectives only.

  ## Examples

      iex> x = ExPulp.Variable.new("x")
      iex> y = ExPulp.Variable.new("y")
      iex> expr = ExPulp.Expression.new([{x, 2}, {y, 3}], 1.0)
      iex> ExPulp.Expression.to_string(expr)
      "2*x + 3*y + 1"

  Expressions have a human-readable inspect format:

      iex> x = ExPulp.Variable.new("x")
      iex> ExPulp.Expression.new([{x, 3}], 2)
      #Expression<3*x + 2>
  """

  alias ExPulp.Variable

  @type quad_key :: {Variable.t(), Variable.t()}

  @type t :: %__MODULE__{
          terms: %{Variable.t() => number()},
          quad_terms: %{quad_key() => number()},
          constant: number()
        }

  defstruct terms: %{}, quad_terms: %{}, constant: 0.0

  @doc """
  Creates an expression from a list of `{variable, coefficient}` pairs
  and an optional constant. Duplicate variables have their coefficients summed.
  Zero-coefficient terms are dropped.

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
  Merges both linear and quadratic terms.

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
      |> drop_zeros()

    quad_terms =
      Map.merge(a.quad_terms, b.quad_terms, fn _key, c1, c2 -> Kernel.+(c1, c2) end)
      |> drop_zeros()

    %__MODULE__{terms: terms, quad_terms: quad_terms, constant: Kernel.+(a.constant, b.constant)}
  end

  @doc """
  Subtracts the second expression from the first.

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
  Multiplies two expressions. Supports:

  - Scalar × scalar → scalar
  - Scalar × variable/expression → scaled expression
  - Variable × variable → quadratic term
  - Expression × expression → distributes into linear + quadratic terms

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

  Variable × variable produces a quadratic term:

      iex> x = ExPulp.Variable.new("x")
      iex> y = ExPulp.Variable.new("y")
      iex> ExPulp.Expression.to_string(ExPulp.Expression.multiply(ExPulp.Expression.from_variable(x), ExPulp.Expression.from_variable(y)))
      "x*y"

  Expression × expression distributes:

      iex> x = ExPulp.Variable.new("x")
      iex> y = ExPulp.Variable.new("y")
      iex> a = ExPulp.Expression.add(ExPulp.Expression.from_variable(x), ExPulp.Expression.from_variable(y))
      iex> ExPulp.Expression.to_string(ExPulp.Expression.multiply(a, a))
      "x^2 + y^2 + 2*x*y"
  """
  @spec multiply(t() | Variable.t() | number(), t() | Variable.t() | number()) :: t()
  def multiply(a, b) when is_number(a) and is_number(b), do: wrap(Kernel.*(a, b))

  def multiply(n, %Variable{} = var) when is_number(n), do: from_variable(var, n)
  def multiply(%Variable{} = var, n) when is_number(n), do: from_variable(var, n)

  def multiply(n, %__MODULE__{} = expr) when is_number(n), do: scale(expr, n)
  def multiply(%__MODULE__{} = expr, n) when is_number(n), do: scale(expr, n)

  def multiply(%Variable{} = a, %Variable{} = b) do
    %__MODULE__{quad_terms: %{quad_key(a, b) => 1}}
  end

  def multiply(%Variable{} = var, %__MODULE__{} = expr), do: multiply(from_variable(var), expr)
  def multiply(%__MODULE__{} = expr, %Variable{} = var), do: multiply(expr, from_variable(var))

  def multiply(%__MODULE__{} = a, %__MODULE__{} = b) do
    if quadratic?(a) or quadratic?(b) do
      raise ArgumentError,
            "cannot multiply expressions that are already quadratic (would produce cubic+ terms)"
    end

    # Distribute: (a_terms + a_const) * (b_terms + b_const)
    # = a_terms*b_terms + a_terms*b_const + a_const*b_terms + a_const*b_const

    # quad: a_terms * b_terms
    quad_terms =
      for {va, ca} <- a.terms, {vb, cb} <- b.terms, reduce: %{} do
        acc ->
          key = quad_key(va, vb)
          Map.update(acc, key, Kernel.*(ca, cb), &Kernel.+(&1, Kernel.*(ca, cb)))
      end
      |> drop_zeros()

    # linear: a_terms * b_const + a_const * b_terms
    terms =
      for {v, c} <- a.terms, into: %{} do
        {v, Kernel.*(c, b.constant)}
      end

    terms =
      Enum.reduce(b.terms, terms, fn {v, c}, acc ->
        Map.update(acc, v, Kernel.*(c, a.constant), &Kernel.+(&1, Kernel.*(c, a.constant)))
      end)
      |> drop_zeros()

    # constant: a_const * b_const
    constant = Kernel.*(a.constant, b.constant)

    %__MODULE__{terms: terms, quad_terms: quad_terms, constant: constant}
  end

  @doc """
  Divides an expression by a scalar.

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
  Scales an expression by a scalar factor. Scales linear terms, quadratic terms,
  and constant.

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
      quad_terms = Map.new(expr.quad_terms, fn {key, coeff} -> {key, Kernel.*(coeff, factor)} end)
      %__MODULE__{terms: terms, quad_terms: quad_terms, constant: Kernel.*(expr.constant, factor)}
    end
  end

  @doc """
  Returns true if the expression has quadratic terms.

  ## Examples

      iex> ExPulp.Expression.quadratic?(ExPulp.Expression.new())
      false

      iex> x = ExPulp.Variable.new("x")
      iex> ExPulp.Expression.quadratic?(ExPulp.Expression.multiply(x, x))
      true
  """
  @spec quadratic?(t()) :: boolean()
  def quadratic?(%__MODULE__{quad_terms: qt}), do: map_size(qt) > 0

  @doc """
  Evaluates the expression given a map of variable names to values.
  Returns nil if any variable has no value.

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
    with {:ok, linear_sum} <- evaluate_linear(expr.terms, values, expr.constant),
         {:ok, quad_sum} <- evaluate_quad(expr.quad_terms, values, 0.0) do
      Kernel.+(linear_sum, quad_sum)
    end
  end

  defp evaluate_linear(terms, values, acc) do
    Enum.reduce_while(terms, {:ok, acc}, fn {%Variable{name: name}, coeff}, {:ok, sum} ->
      case Map.fetch(values, name) do
        {:ok, val} -> {:cont, {:ok, Kernel.+(sum, Kernel.*(coeff, val))}}
        :error -> {:halt, nil}
      end
    end)
  end

  defp evaluate_quad(quad_terms, values, acc) do
    Enum.reduce_while(quad_terms, {:ok, acc}, fn {{%Variable{name: na}, %Variable{name: nb}},
                                                  coeff},
                                                 {:ok, sum} ->
      with {:ok, va} <- Map.fetch(values, na),
           {:ok, vb} <- Map.fetch(values, nb) do
        {:cont, {:ok, Kernel.+(sum, Kernel.*(coeff, Kernel.*(va, vb)))}}
      else
        :error -> {:halt, nil}
      end
    end)
  end

  @doc """
  Returns the sorted list of variables in this expression (sorted by name).
  Includes variables from both linear and quadratic terms.

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
    linear_vars = Map.keys(expr.terms)

    quad_vars =
      Enum.flat_map(expr.quad_terms, fn {{va, vb}, _} ->
        if va == vb, do: [va], else: [va, vb]
      end)

    (linear_vars ++ quad_vars)
    |> Enum.uniq_by(& &1.name)
    |> Enum.sort_by(& &1.name)
  end

  @doc """
  Returns a human-readable string representation of the expression.

  Quadratic terms are shown as `x^2` (self-product) or `x*y` (cross-product),
  printed before linear terms.

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

      iex> x = ExPulp.Variable.new("x")
      iex> y = ExPulp.Variable.new("y")
      iex> expr = ExPulp.Expression.multiply(ExPulp.Expression.from_variable(x), ExPulp.Expression.from_variable(y))
      iex> ExPulp.Expression.to_string(expr)
      "x*y"
  """
  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{} = expr) do
    parts = []

    # Quadratic terms first (sorted: self-products, then cross-products, alphabetically)
    parts = parts ++ format_quad_terms(expr.quad_terms)

    # Linear terms
    vars = expr.terms |> Map.keys() |> Enum.sort_by(& &1.name)

    linear_parts =
      Enum.map(vars, fn var ->
        {Map.fetch!(expr.terms, var), var.name}
      end)

    parts = parts ++ linear_parts

    # Format all term parts
    terms_str =
      parts
      |> Enum.with_index()
      |> Enum.map(fn {{coeff, label}, idx} ->
        format_term(coeff, label, idx == 0)
      end)
      |> Enum.join("")

    constant_str = format_constant(expr.constant, terms_str == "")
    result = terms_str <> constant_str

    if result == "", do: "0", else: result
  end

  # Returns list of {coeff, label} for quadratic terms
  defp format_quad_terms(quad_terms) when map_size(quad_terms) == 0, do: []

  defp format_quad_terms(quad_terms) do
    quad_terms
    |> Enum.map(fn {{va, vb}, coeff} ->
      label = if va.name == vb.name, do: "#{va.name}^2", else: "#{va.name}*#{vb.name}"
      {coeff, label}
    end)
    |> Enum.sort_by(fn {_coeff, label} ->
      # Self-products first, then cross-products, alphabetically
      if String.contains?(label, "^2"), do: {0, label}, else: {1, label}
    end)
  end

  defp format_term(coeff, label, first?) do
    abs_coeff = abs(coeff)

    coeff_str =
      cond do
        abs_coeff == 1 -> label
        abs_coeff == trunc(abs_coeff) -> "#{trunc(abs_coeff)}*#{label}"
        true -> "#{abs_coeff}*#{label}"
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

  defp format_constant(c, true), do: format_number(c)
  defp format_constant(c, false) when c > 0, do: " + #{format_number(c)}"
  defp format_constant(c, false), do: " - #{format_number(abs(c))}"

  defp format_number(n) when is_float(n) and n == trunc(n), do: "#{trunc(n)}"
  defp format_number(n), do: "#{n}"

  # Canonical ordering for quadratic key: sort by variable name
  defp quad_key(%Variable{} = a, %Variable{} = b) do
    if a.name <= b.name, do: {a, b}, else: {b, a}
  end

  defp drop_zeros(map) do
    map |> Enum.reject(fn {_k, v} -> v == 0 end) |> Map.new()
  end
end

defimpl String.Chars, for: ExPulp.Expression do
  def to_string(expr), do: ExPulp.Expression.to_string(expr)
end

defimpl Inspect, for: ExPulp.Expression do
  def inspect(expr, _opts) do
    "#Expression<#{ExPulp.Expression.to_string(expr)}>"
  end
end
