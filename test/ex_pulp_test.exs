defmodule ExPulpTest do
  use ExUnit.Case

  require ExPulp

  @moduletag :solver

  test "DSL end-to-end: simple minimize" do
    problem =
      ExPulp.model "simple", :minimize do
        x = var(low: 0, high: 10)
        y = var(low: 0, high: 10)

        minimize x + y
        subject_to "sum_ge_5", x + y >= 5
      end

    {:ok, result} = ExPulp.solve(problem)
    assert result.status == :optimal
    assert_in_delta result.objective, 5.0, 1.0e-6
    total = result.variables["x"] + result.variables["y"]
    assert_in_delta total, 5.0, 1.0e-6
  end

  test "DSL end-to-end: maximize" do
    problem =
      ExPulp.model "maxtest", :maximize do
        x = var(low: 0, high: 10)

        maximize 2 * x
        subject_to "ub", x <= 7
      end

    {:ok, result} = ExPulp.solve(problem)
    assert result.status == :optimal
    assert_in_delta result.variables["x"], 7.0, 1.0e-6
    assert_in_delta result.objective, 14.0, 1.0e-6
  end

  test "DSL end-to-end: integer knapsack" do
    problem =
      ExPulp.model "knapsack", :maximize do
        x = var(low: 0, high: 5, category: :integer)
        y = var(low: 0, high: 5, category: :integer)

        maximize 4 * x + 5 * y
        subject_to "weight", 3 * x + 4 * y <= 12
      end

    {:ok, result} = ExPulp.solve(problem)
    assert result.status == :optimal
    assert result.variables["x"] == 4.0
    assert result.variables["y"] == 0.0
  end

  test "DSL end-to-end: infeasible" do
    problem =
      ExPulp.model "infeasible", :minimize do
        x = var(low: 0, high: 5)

        minimize x
        subject_to "too_high", x >= 10
      end

    {:ok, result} = ExPulp.solve(problem)
    assert result.status == :infeasible
  end

  test "value/2 helper" do
    problem =
      ExPulp.model "val_test", :minimize do
        x = var(low: 0, high: 10)

        minimize x
        subject_to "lb", x >= 3
      end

    {:ok, result} = ExPulp.solve(problem)
    assert_in_delta ExPulp.value(result, "x"), 3.0, 1.0e-6
  end

  test "functional API (no DSL)" do
    alias ExPulp.{Variable, Expression, Constraint, Problem}

    x = Variable.new("x", low: 0, high: 10)
    y = Variable.new("y", low: 0, high: 10)

    problem =
      Problem.new("functional", :minimize)
      |> Problem.set_objective(Expression.new([{x, 1}, {y, 1}]))
      |> Problem.add_constraint(
        Constraint.geq(Expression.new([{x, 1}, {y, 1}]), 5),
        "sum_ge_5"
      )

    {:ok, result} = ExPulp.solve(problem)
    assert result.status == :optimal
    assert_in_delta result.objective, 5.0, 1.0e-6
  end
end
