defmodule ExPulp.ProblemTest do
  use ExUnit.Case, async: true

  alias ExPulp.{Variable, Expression, Constraint, Problem}

  setup do
    x = Variable.new("x", low: 0, high: 10)
    y = Variable.new("y", low: 0, high: 10)
    %{x: x, y: y}
  end

  test "new/2 creates problem" do
    p = Problem.new("test", :minimize)
    assert p.name == "test"
    assert p.sense == :minimize
    assert p.constraints == []
    assert p.variables == %{}
  end

  test "new/2 sanitizes spaces in name" do
    p = Problem.new("my problem", :maximize)
    assert p.name == "my_problem"
  end

  test "add_variable/2 registers variable", %{x: x} do
    p = Problem.new("test") |> Problem.add_variable(x)
    assert Map.has_key?(p.variables, "x")
  end

  test "add_variables/2 registers multiple", %{x: x, y: y} do
    p = Problem.new("test") |> Problem.add_variables([x, y])
    assert map_size(p.variables) == 2
  end

  test "set_objective/2 sets objective and registers variables", %{x: x, y: y} do
    expr = Expression.new([{x, 1}, {y, 2}])
    p = Problem.new("test") |> Problem.set_objective(expr)
    assert p.objective == expr
    assert Map.has_key?(p.variables, "x")
    assert Map.has_key?(p.variables, "y")
  end

  test "add_constraint/3 with name", %{x: x} do
    c = Constraint.geq(Expression.new([{x, 1}]), 5)
    p = Problem.new("test") |> Problem.add_constraint(c, "my_constraint")
    assert length(p.constraints) == 1
    assert {"my_constraint", ^c} = hd(p.constraints)
    assert Map.has_key?(p.variables, "x")
  end

  test "add_constraint/2 auto-generates name", %{x: x, y: y} do
    c1 = Constraint.geq(Expression.new([{x, 1}]), 5)
    c2 = Constraint.leq(Expression.new([{y, 1}]), 8)

    p =
      Problem.new("test")
      |> Problem.add_constraint(c1)
      |> Problem.add_constraint(c2)

    assert [{"_C1", _}, {"_C2", _}] = p.constraints
  end

  test "variables_sorted/1 returns sorted", %{x: x, y: y} do
    p =
      Problem.new("test")
      |> Problem.add_variables([y, x])

    sorted = Problem.variables_sorted(p)
    assert [%{name: "x"}, %{name: "y"}] = sorted
  end

  test "mip?/1 detects integer variables" do
    x = Variable.new("x", category: :integer)
    y = Variable.new("y")

    p =
      Problem.new("test")
      |> Problem.add_variables([x, y])

    assert Problem.mip?(p)
  end

  test "mip?/1 returns false for continuous only", %{x: x, y: y} do
    p =
      Problem.new("test")
      |> Problem.add_variables([x, y])

    refute Problem.mip?(p)
  end
end
