defmodule ExPulp.Variable do
  @moduledoc """
  A linear programming variable with bounds and category.

  Variables are the building blocks of LP/MIP models. Each variable has a name,
  optional lower and upper bounds, and a category (`:continuous`, `:integer`, or
  `:binary`).

  ## Creating variables

      iex> x = ExPulp.Variable.new("x")
      iex> x.name
      "x"
      iex> x.category
      :continuous

  Binary variables are normalized to integer variables with bounds `[0, 1]`:

      iex> b = ExPulp.Variable.new("b", category: :binary)
      iex> b.category
      :integer
      iex> {b.low, b.high}
      {0, 1}

  ## Name sanitization

  Illegal characters (`-`, `+`, `[`, `]`, ` `, `-`, `>`, `/`) are replaced
  with underscores to produce LP-format-safe names:

      iex> v = ExPulp.Variable.new("my-var/test")
      iex> v.name
      "my_var_test"

  ## Inspection

  Variables have a human-readable inspect format:

      iex> ExPulp.Variable.new("x")
      #Variable<x free>

      iex> ExPulp.Variable.new("x", low: 0, high: 10, category: :integer)
      #Variable<0 <= x <= 10, integer>

      iex> ExPulp.Variable.new("b", category: :binary)
      #Variable<0 <= b <= 1, binary>
  """

  @type category :: :continuous | :integer | :binary

  @type t :: %__MODULE__{
          name: String.t(),
          low: number() | nil,
          high: number() | nil,
          category: category()
        }

  @enforce_keys [:name]
  defstruct [:name, low: nil, high: nil, category: :continuous]

  @illegal_chars ~c"-+[] ->/"
  @replacement ?_

  @doc """
  Creates a new variable.

  ## Options
    * `:low` - lower bound (default: `nil` = unbounded)
    * `:high` - upper bound (default: `nil` = unbounded)
    * `:category` - `:continuous` (default), `:integer`, or `:binary`

  Binary variables are normalized to integer with bounds `[0, 1]`.

  ## Examples

  A continuous variable with no bounds:

      iex> x = ExPulp.Variable.new("x")
      iex> {x.name, x.category, x.low, x.high}
      {"x", :continuous, nil, nil}

  A bounded integer variable:

      iex> n = ExPulp.Variable.new("n", low: 1, high: 10, category: :integer)
      iex> {n.category, n.low, n.high}
      {:integer, 1, 10}

  Binary variables are stored as integer `[0, 1]`:

      iex> b = ExPulp.Variable.new("b", category: :binary)
      iex> {b.category, b.low, b.high}
      {:integer, 0, 1}

  Illegal characters in names are replaced with underscores:

      iex> v = ExPulp.Variable.new("x[0]->y")
      iex> v.name
      "x_0___y"
  """
  @spec new(String.t(), keyword()) :: t()
  def new(name, opts \\ []) when is_binary(name) do
    category = Keyword.get(opts, :category, :continuous)
    low = Keyword.get(opts, :low)
    high = Keyword.get(opts, :high)

    {category, low, high} =
      case category do
        :binary -> {:integer, 0, 1}
        other -> {other, low, high}
      end

    %__MODULE__{
      name: sanitize_name(name),
      low: low,
      high: high,
      category: category
    }
  end

  @doc """
  Returns `true` if the variable is binary (integer with `0`/`1` bounds).

  ## Examples

      iex> ExPulp.Variable.binary?(ExPulp.Variable.new("b", category: :binary))
      true

      iex> ExPulp.Variable.binary?(ExPulp.Variable.new("x"))
      false

      iex> ExPulp.Variable.binary?(ExPulp.Variable.new("n", category: :integer))
      false
  """
  @spec binary?(t()) :: boolean()
  def binary?(%__MODULE__{category: :integer, low: 0, high: 1}), do: true
  def binary?(%__MODULE__{}), do: false

  @doc """
  Returns `true` if the variable has the default positive bounds
  (`low: 0`, `high: nil`, `category: :continuous`).

  This is used internally to detect the common LP convention where variables
  default to non-negative.

  ## Examples

      iex> ExPulp.Variable.default_positive?(ExPulp.Variable.new("x", low: 0))
      true

      iex> ExPulp.Variable.default_positive?(ExPulp.Variable.new("x"))
      false

      iex> ExPulp.Variable.default_positive?(ExPulp.Variable.new("x", low: 0, category: :integer))
      false
  """
  @spec default_positive?(t()) :: boolean()
  def default_positive?(%__MODULE__{low: 0, high: nil, category: :continuous}), do: true
  def default_positive?(%__MODULE__{}), do: false

  defp sanitize_name(name) do
    name
    |> String.to_charlist()
    |> Enum.map(fn c -> if c in @illegal_chars, do: @replacement, else: c end)
    |> List.to_string()
  end
end

defimpl String.Chars, for: ExPulp.Variable do
  def to_string(%ExPulp.Variable{name: name}), do: name
end

defimpl Inspect, for: ExPulp.Variable do
  def inspect(%ExPulp.Variable{} = var, _opts) do
    bounds =
      case {var.low, var.high} do
        {nil, nil} -> "#{var.name} free"
        {low, nil} -> "#{low} <= #{var.name}"
        {nil, high} -> "#{var.name} <= #{high}"
        {low, high} when low == high -> "#{var.name} = #{low}"
        {low, high} -> "#{low} <= #{var.name} <= #{high}"
      end

    cat =
      cond do
        ExPulp.Variable.binary?(var) -> ", binary"
        var.category == :integer -> ", integer"
        true -> ""
      end

    "#Variable<#{bounds}#{cat}>"
  end
end
