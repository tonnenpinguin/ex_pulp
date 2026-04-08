defmodule ExPulp.ConstraintTest do
  use ExUnit.Case, async: true

  alias ExPulp.{Variable, Expression, Constraint}

  doctest ExPulp.Constraint

  setup do
    x = Variable.new("x", low: 0, high: 10)
    y = Variable.new("y", low: 0, high: 10)
    %{x: x, y: y}
  end

  test "leq with expression and number", %{x: x, y: y} do
    expr = Expression.new([{x, 1}, {y, 1}])
    c = Constraint.leq(expr, 10)
    assert c.sense == :leq
    assert c.rhs == 10.0
    assert c.expression.terms[x] == 1
  end

  test "geq with expression and number", %{x: x} do
    expr = Expression.new([{x, 2}])
    c = Constraint.geq(expr, 5)
    assert c.sense == :geq
    assert c.rhs == 5.0
  end

  test "eq with expression and number", %{x: x} do
    expr = Expression.new([{x, 1}])
    c = Constraint.eq(expr, 3)
    assert c.sense == :eq
    assert c.rhs == 3.0
  end

  test "constraint with two expressions", %{x: x, y: y} do
    a = Expression.new([{x, 1}])
    b = Expression.new([{y, 1}])
    c = Constraint.geq(a, b)
    assert c.sense == :geq
    assert c.rhs == 0.0
    # Should be x - y >= 0
    assert c.expression.terms[x] == 1
    assert c.expression.terms[y] == -1
  end

  test "constraint with variable and number", %{x: x} do
    c = Constraint.leq(x, 5)
    assert c.sense == :leq
    assert c.rhs == 5.0
    assert c.expression.terms[x] == 1
  end

  test "constraint number on left flips sense", %{x: x} do
    c = Constraint.leq(5, x)
    # 5 <= x  =>  -x >= -5
    assert c.sense == :geq
    assert c.rhs == -5.0
    assert c.expression.terms[x] == -1
  end

  test "effective_rhs with constant in expression", %{x: x} do
    expr = Expression.new([{x, 1}], 3.0)
    c = Constraint.leq(expr, 10)
    # effective rhs = 10 - 3 = 7
    assert Constraint.effective_rhs(c) == 7.0
  end

  test "sense_string" do
    assert Constraint.sense_string(:leq) == "<="
    assert Constraint.sense_string(:geq) == ">="
    assert Constraint.sense_string(:eq) == "="
  end
end
