defmodule ExPulp.StringCharsTest do
  use ExUnit.Case, async: true

  alias ExPulp.{Variable, Expression, Constraint}

  test "Variable to_string returns name" do
    var = Variable.new("x")
    assert to_string(var) == "x"
  end

  test "Expression to_string" do
    x = Variable.new("x")
    y = Variable.new("y")
    expr = Expression.new([{x, 2}, {y, -1}], 3.0)
    assert to_string(expr) == "2*x - y + 3"
  end

  test "Expression to_string with single variable" do
    x = Variable.new("x")
    assert to_string(Expression.from_variable(x)) == "x"
  end

  test "Expression to_string zero" do
    assert to_string(Expression.new()) == "0"
  end

  test "Expression to_string negative constant only" do
    assert to_string(Expression.new([], -7.0)) == "-7"
  end

  test "Expression to_string float coefficient" do
    x = Variable.new("x")
    expr = Expression.new([{x, 0.5}])
    assert to_string(expr) == "0.5*x"
  end

  test "Constraint to_string" do
    x = Variable.new("x")
    c = Constraint.geq(Expression.from_variable(x), 5)
    assert to_string(c) == "x >= 5"
  end

  test "Constraint to_string with expression constant" do
    x = Variable.new("x")
    # x + 3 <= 10  => effective RHS is 7
    expr = Expression.new([{x, 1}], 3.0)
    c = Constraint.leq(expr, 10)
    assert to_string(c) == "x <= 7"
  end

  test "string interpolation works" do
    x = Variable.new("x")
    expr = Expression.from_variable(x, 2)
    c = Constraint.geq(expr, 5)
    assert "objective: #{expr}" == "objective: 2*x"
    assert "constraint: #{c}" == "constraint: 2*x >= 5"
  end
end
