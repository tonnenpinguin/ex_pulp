defmodule ExPulp.ExpressionTest do
  use ExUnit.Case, async: true

  alias ExPulp.{Variable, Expression}

  doctest ExPulp.Expression

  setup do
    x = Variable.new("x", low: 0, high: 10)
    y = Variable.new("y", low: 0, high: 10)
    %{x: x, y: y}
  end

  test "new/0 creates empty expression" do
    expr = Expression.new()
    assert expr.terms == %{}
    assert expr.constant == 0.0
  end

  test "new/1 from term list", %{x: x, y: y} do
    expr = Expression.new([{x, 2}, {y, 3}])
    assert expr.terms[x] == 2
    assert expr.terms[y] == 3
    assert expr.constant == 0.0
  end

  test "new/2 with constant", %{x: x} do
    expr = Expression.new([{x, 1}], 5.0)
    assert expr.terms[x] == 1
    assert expr.constant == 5.0
  end

  test "new/1 sums duplicate variables", %{x: x} do
    expr = Expression.new([{x, 2}, {x, 3}])
    assert expr.terms[x] == 5
  end

  test "new/1 drops zero-coefficient terms", %{x: x, y: y} do
    expr = Expression.new([{x, 3}, {x, -3}, {y, 1}])
    refute Map.has_key?(expr.terms, x)
    assert expr.terms[y] == 1
  end

  test "from_variable/1", %{x: x} do
    expr = Expression.from_variable(x)
    assert expr.terms[x] == 1
    assert expr.constant == 0.0
  end

  test "from_variable/2 with coefficient", %{x: x} do
    expr = Expression.from_variable(x, 5)
    assert expr.terms[x] == 5
  end

  test "from_variable/2 with zero coefficient", %{x: x} do
    expr = Expression.from_variable(x, 0)
    assert expr.terms == %{}
  end

  test "wrap/1 passes through expressions" do
    expr = %Expression{}
    assert Expression.wrap(expr) == expr
  end

  test "wrap/1 wraps variable", %{x: x} do
    expr = Expression.wrap(x)
    assert expr.terms[x] == 1
  end

  test "wrap/1 wraps number" do
    expr = Expression.wrap(42)
    assert expr.constant == 42.0
    assert expr.terms == %{}
  end

  test "add/2 two expressions", %{x: x, y: y} do
    a = Expression.new([{x, 2}], 1.0)
    b = Expression.new([{x, 3}, {y, 4}], 2.0)
    result = Expression.add(a, b)
    assert result.terms[x] == 5
    assert result.terms[y] == 4
    assert result.constant == 3.0
  end

  test "add/2 expression and variable", %{x: x, y: y} do
    a = Expression.new([{x, 2}])
    result = Expression.add(a, y)
    assert result.terms[x] == 2
    assert result.terms[y] == 1
  end

  test "add/2 expression and number", %{x: x} do
    a = Expression.new([{x, 2}], 3.0)
    result = Expression.add(a, 7)
    assert result.terms[x] == 2
    assert result.constant == 10.0
  end

  test "add/2 cancels terms to zero", %{x: x} do
    a = Expression.new([{x, 2}])
    b = Expression.new([{x, -2}])
    result = Expression.add(a, b)
    refute Map.has_key?(result.terms, x)
  end

  test "subtract/2", %{x: x, y: y} do
    a = Expression.new([{x, 5}, {y, 3}])
    b = Expression.new([{x, 2}, {y, 3}])
    result = Expression.subtract(a, b)
    assert result.terms[x] == 3
    refute Map.has_key?(result.terms, y)
  end

  test "multiply/2 scalar * expression", %{x: x} do
    expr = Expression.new([{x, 3}], 2.0)
    result = Expression.multiply(2, expr)
    assert result.terms[x] == 6
    assert result.constant == 4.0
  end

  test "multiply/2 scalar * variable", %{x: x} do
    result = Expression.multiply(5, x)
    assert result.terms[x] == 5
  end

  test "multiply/2 produces quadratic terms", %{x: x, y: y} do
    a = Expression.new([{x, 1}])
    b = Expression.new([{y, 1}])
    result = Expression.multiply(a, b)

    assert Expression.quadratic?(result)
    assert Expression.to_string(result) == "x*y"
  end

  test "multiply/2 raises on cubic (quadratic * linear)", %{x: x, y: y} do
    quad = Expression.multiply(x, x)
    linear = Expression.from_variable(y)

    assert_raise ArgumentError, ~r/cubic/, fn ->
      Expression.multiply(quad, linear)
    end
  end

  test "multiply/2 constant expression * expression", %{x: x} do
    a = Expression.new([], 3.0)
    b = Expression.new([{x, 2}], 1.0)
    result = Expression.multiply(a, b)
    assert result.terms[x] == 6
    assert result.constant == 3.0
  end

  test "divide/2", %{x: x} do
    expr = Expression.new([{x, 6}], 4.0)
    result = Expression.divide(expr, 2)
    assert result.terms[x] == 3.0
    assert result.constant == 2.0
  end

  test "negate/1", %{x: x} do
    expr = Expression.new([{x, 3}], 2.0)
    result = Expression.negate(expr)
    assert result.terms[x] == -3
    assert result.constant == -2.0
  end

  test "scale/2 by zero", %{x: x} do
    expr = Expression.new([{x, 3}], 2.0)
    result = Expression.scale(expr, 0)
    assert result.terms == %{}
    assert result.constant == 0
  end

  test "evaluate/2", %{x: x, y: y} do
    expr = Expression.new([{x, 2}, {y, 3}], 1.0)
    assert Expression.evaluate(expr, %{"x" => 4.0, "y" => 2.0}) == 15.0
  end

  test "evaluate/2 returns nil for missing variable", %{x: x} do
    expr = Expression.new([{x, 2}])
    assert Expression.evaluate(expr, %{}) == nil
  end

  test "sorted_variables/1", %{x: x, y: y} do
    expr = Expression.new([{y, 1}, {x, 1}])
    assert Expression.sorted_variables(expr) == [x, y]
  end
end
