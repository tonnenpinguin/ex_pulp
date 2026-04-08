defmodule ExPulp.DSL.Helpers do
  @moduledoc """
  Helper functions available inside `ExPulp.model/3` blocks.

  These functions are automatically imported within a `model` block:

      ExPulp.model "example", :minimize do
        x = var(low: 0, high: 10)
        costs = %{1 => 3.0, 2 => 5.0, 3 => 1.0}
        items = lp_vars("item", 1..3, low: 0)

        minimize lp_weighted_sum(costs, items)
        subject_to "budget", lp_sum(for i <- 1..3, do: items[i]) <= 100
      end

  They also work outside `model` blocks when called with their full module path.
  """

  alias ExPulp.{Variable, Expression}

  @doc """
  Creates a new variable.

  Inside a `model` block, the variable name is automatically deduced from
  the assignment target — `x = var(low: 0)` creates a variable named `"x"`.
  When called directly, the name must be provided as the first argument.

  ## Options
    * `:low` - lower bound (default: `nil`, unbounded)
    * `:high` - upper bound (default: `nil`, unbounded)
    * `:category` - `:continuous` (default), `:integer`, or `:binary`

  ## Examples

      iex> v = ExPulp.DSL.Helpers.var("x", low: 0, high: 10)
      iex> v.name
      "x"

      iex> v = ExPulp.DSL.Helpers.var("y", category: :binary)
      iex> v.low
      0

      iex> v = ExPulp.DSL.Helpers.var("z")
      iex> v.category
      :continuous
  """
  @spec var(String.t(), keyword()) :: Variable.t()
  def var(name, opts \\ []) do
    Variable.new(name, Keyword.delete(opts, :name))
  end

  @doc """
  Creates a map of indexed variables.
  Equivalent to PuLP's `LpVariable.dicts`.

  Returns `%{key => %Variable{}}` where each variable is named
  `"prefix_key"`.

  ## Single dimension

      iex> vars = ExPulp.DSL.Helpers.lp_vars("x", 1..3, low: 0)
      iex> map_size(vars)
      3
      iex> vars[2].name
      "x_2"

      iex> vars = ExPulp.DSL.Helpers.lp_vars("x", ["a", "b"])
      iex> Map.keys(vars) |> Enum.sort()
      ["a", "b"]

  ## Multiple dimensions

  Pass a list of enumerables to create variables indexed by tuples.
  Ranges, lists, and any enumerable can be mixed:

      iex> vars = ExPulp.DSL.Helpers.lp_vars("flow", [[:a, :b], 1..2], low: 0)
      iex> map_size(vars)
      4
      iex> vars[{:a, 1}].name
      "flow_a_1"

  Index values are converted to name segments automatically — atoms, strings,
  integers, floats, and `DateTime` (as unix timestamp) are all supported.
  """
  @spec lp_vars(String.t(), Enumerable.t() | [Enumerable.t()], keyword()) ::
          %{any() => Variable.t()}
  def lp_vars(prefix, indices, opts \\ [])

  def lp_vars(prefix, [first | _] = indices, opts) when is_list(first) or is_struct(first, Range) do
    clean_opts = Keyword.delete(opts, :name)

    indices
    |> cartesian_product()
    |> Enum.into(%{}, fn key_tuple ->
      name_suffix = key_tuple |> Tuple.to_list() |> Enum.map_join("_", &to_name/1)
      {key_tuple, Variable.new("#{prefix}_#{name_suffix}", clean_opts)}
    end)
  end

  def lp_vars(prefix, indices, opts) do
    for i <- indices, into: %{} do
      {i, Variable.new("#{prefix}_#{to_name(i)}", Keyword.delete(opts, :name))}
    end
  end

  defp cartesian_product([single]), do: Enum.map(single, &{&1})

  defp cartesian_product([head | tail]) do
    tail_product = cartesian_product(tail)

    for h <- head, t <- tail_product do
      Tuple.insert_at(t, 0, h)
    end
  end

  defp to_name(value) when is_binary(value), do: value
  defp to_name(value) when is_atom(value), do: Atom.to_string(value)
  defp to_name(value) when is_integer(value), do: Integer.to_string(value)
  defp to_name(value) when is_float(value), do: Float.to_string(value)

  defp to_name(value) when is_tuple(value),
    do: value |> Tuple.to_list() |> Enum.map_join("_", &to_name/1)

  defp to_name(%DateTime{} = dt), do: dt |> DateTime.to_unix() |> Integer.to_string()
  defp to_name(value), do: inspect(value)

  @doc """
  Creates a map of indexed binary (0/1) variables.

  Shorthand for `lp_vars(prefix, indices, category: :binary)`.

  ## Examples

      iex> vars = ExPulp.DSL.Helpers.lp_binary_vars("use", [:a, :b, :c])
      iex> map_size(vars)
      3
      iex> vars[:a].low
      0
      iex> vars[:a].high
      1
      iex> vars[:a].category
      :integer
  """
  @spec lp_binary_vars(String.t(), Enumerable.t()) :: %{any() => Variable.t()}
  def lp_binary_vars(prefix, indices) do
    lp_vars(prefix, indices, category: :binary)
  end

  @doc """
  Creates a map of indexed integer variables.

  Shorthand for `lp_vars(prefix, indices, category: :integer)`.
  Accepts the same options as `lp_vars/3`.

  ## Examples

      iex> vars = ExPulp.DSL.Helpers.lp_integer_vars("n", 1..3, low: 0, high: 100)
      iex> map_size(vars)
      3
      iex> vars[1].category
      :integer
      iex> vars[1].low
      0

      iex> vars = ExPulp.DSL.Helpers.lp_integer_vars("count", [:a, :b])
      iex> vars[:a].category
      :integer
  """
  @spec lp_integer_vars(String.t(), Enumerable.t(), keyword()) :: %{any() => Variable.t()}
  def lp_integer_vars(prefix, indices, opts \\ []) do
    lp_vars(prefix, indices, Keyword.put(opts, :category, :integer))
  end

  @doc """
  Sums a list of variables and/or expressions into a single expression.
  Equivalent to PuLP's `lpSum`.

  Works naturally with comprehensions:

      lp_sum(for i <- items, do: costs[i] * vars[i])

  ## Examples

      iex> alias ExPulp.{Variable, Expression}
      iex> x = Variable.new("x")
      iex> y = Variable.new("y")
      iex> expr = ExPulp.DSL.Helpers.lp_sum([Expression.from_variable(x), Expression.from_variable(y)])
      iex> Expression.to_string(expr)
      "x + y"

      iex> alias ExPulp.Expression
      iex> expr = ExPulp.DSL.Helpers.lp_sum([Expression.wrap(1), Expression.wrap(2), Expression.wrap(3)])
      iex> expr.constant
      6.0
  """
  @spec lp_sum([Variable.t() | Expression.t() | number()]) :: Expression.t()
  def lp_sum(list) when is_list(list) do
    Enum.reduce(list, %Expression{}, &Expression.add(&2, &1))
  end

  @doc """
  Computes the weighted sum of two maps with matching keys.

  For every key present in **both** maps, multiplies the coefficient by the
  variable and sums the results. Keys present in only one map are ignored.

      lp_weighted_sum(costs, vars)
      # equivalent to: lp_sum(for {k, c} <- costs, Map.has_key?(vars, k), do: c * vars[k])

  ## Examples

      iex> alias ExPulp.{Variable, Expression}
      iex> x = Variable.new("x")
      iex> y = Variable.new("y")
      iex> vars = %{a: x, b: y}
      iex> coeffs = %{a: 2, b: 3}
      iex> expr = ExPulp.DSL.Helpers.lp_weighted_sum(coeffs, vars)
      iex> Expression.to_string(expr)
      "2*x + 3*y"

      iex> alias ExPulp.{Variable, Expression}
      iex> x = Variable.new("x")
      iex> vars = %{a: x, b: Variable.new("y")}
      iex> coeffs = %{a: 5}
      iex> expr = ExPulp.DSL.Helpers.lp_weighted_sum(coeffs, vars)
      iex> Expression.to_string(expr)
      "5*x"
  """
  @spec lp_weighted_sum(map(), map()) :: Expression.t()
  def lp_weighted_sum(coefficients, variables)
      when is_map(coefficients) and is_map(variables) do
    coefficients
    |> Enum.reduce(%Expression{}, fn {key, coeff}, acc ->
      case Map.fetch(variables, key) do
        {:ok, var} -> Expression.add(acc, Expression.multiply(coeff, var))
        :error -> acc
      end
    end)
  end

  @doc """
  Computes the dot product of two lists — coefficients and variables.
  Equivalent to PuLP's `lpDot`.

  The lists must be the same length. Each coefficient is paired with the
  corresponding variable by position.

  ## Examples

      iex> alias ExPulp.{Variable, Expression}
      iex> x = Variable.new("x")
      iex> y = Variable.new("y")
      iex> expr = ExPulp.DSL.Helpers.lp_dot([2, 3], [x, y])
      iex> Expression.to_string(expr)
      "2*x + 3*y"

      iex> alias ExPulp.{Variable, Expression}
      iex> a = Variable.new("a")
      iex> expr = ExPulp.DSL.Helpers.lp_dot([0.5], [a])
      iex> Expression.to_string(expr)
      "0.5*a"
  """
  @spec lp_dot([number()], [Variable.t()]) :: Expression.t()
  def lp_dot(coefficients, variables) when is_list(coefficients) and is_list(variables) do
    coefficients
    |> Enum.zip(variables)
    |> Enum.map(fn {coeff, var} -> Expression.from_variable(var, coeff) end)
    |> lp_sum()
  end
end
