defmodule ExPulp.Solver.CBCTest do
  use ExUnit.Case

  alias ExPulp.{Variable, Expression, Constraint, Problem}
  alias ExPulp.Solver.CBC

  @moduletag :solver

  test "available?/0 returns true when cbc is installed" do
    assert CBC.available?()
  end

  test "solve simple minimization" do
    x = Variable.new("x", low: 0, high: 10)
    y = Variable.new("y", low: 0, high: 10)

    problem =
      Problem.new("simple_min", :minimize)
      |> Problem.set_objective(Expression.new([{x, 1}, {y, 1}]))
      |> Problem.add_constraint(Constraint.geq(Expression.new([{x, 1}, {y, 1}]), 5), "sum_ge_5")

    {:ok, result} = CBC.solve(problem)
    assert result.status == :optimal
    assert_in_delta result.variables["x"] + result.variables["y"], 5.0, 1.0e-6
  end

  test "solve simple maximization" do
    x = Variable.new("x", low: 0, high: 10)
    y = Variable.new("y", low: 0, high: 10)

    problem =
      Problem.new("simple_max", :maximize)
      |> Problem.set_objective(Expression.new([{x, 1}, {y, 1}]))
      |> Problem.add_constraint(Constraint.leq(Expression.new([{x, 1}, {y, 1}]), 15), "sum_le_15")

    {:ok, result} = CBC.solve(problem)
    assert result.status == :optimal
    assert_in_delta result.variables["x"] + result.variables["y"], 15.0, 1.0e-6
  end

  test "solve with integer variables" do
    x = Variable.new("x", low: 0, high: 100, category: :integer)

    problem =
      Problem.new("integer", :minimize)
      |> Problem.set_objective(Expression.from_variable(x))
      |> Problem.add_constraint(Constraint.geq(Expression.from_variable(x), 3.7), "lb")

    {:ok, result} = CBC.solve(problem)
    assert result.status == :optimal
    assert result.variables["x"] == 4.0
  end

  test "solve with binary variables" do
    x = Variable.new("x", category: :binary)
    y = Variable.new("y", category: :binary)

    problem =
      Problem.new("binary", :maximize)
      |> Problem.set_objective(Expression.new([{x, 3}, {y, 2}]))
      |> Problem.add_constraint(
        Constraint.leq(Expression.new([{x, 2}, {y, 1}]), 2),
        "capacity"
      )

    {:ok, result} = CBC.solve(problem)
    assert result.status == :optimal
    # x=1, y=0 gives objective 3 (2*1 + 1*0 = 2 <= 2)
    assert result.variables["x"] == 1.0
    assert result.variables["y"] == 0.0
  end

  test "infeasible problem" do
    x = Variable.new("x", low: 0, high: 5)

    problem =
      Problem.new("infeasible", :minimize)
      |> Problem.set_objective(Expression.from_variable(x))
      |> Problem.add_constraint(Constraint.geq(Expression.from_variable(x), 10), "too_high")

    {:ok, result} = CBC.solve(problem)
    assert result.status == :infeasible
  end

  test "solver not found returns error" do
    x = Variable.new("x", low: 0)

    problem =
      Problem.new("test", :minimize)
      |> Problem.set_objective(Expression.from_variable(x))

    assert {:error, {:solver_not_found, _}} = CBC.solve(problem, path: "nonexistent_solver_xyz")
  end
end
