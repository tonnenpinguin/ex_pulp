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

  test "DSL end-to-end: Whiskas diet problem" do
    problem =
      ExPulp.model "whiskas", :minimize do
        ingredients = ~w(chicken beef mutton rice wheat gel)

        costs = %{
          "chicken" => 0.013,
          "beef" => 0.008,
          "mutton" => 0.010,
          "rice" => 0.002,
          "wheat" => 0.005,
          "gel" => 0.001
        }

        protein = %{
          "chicken" => 0.100,
          "beef" => 0.200,
          "mutton" => 0.150,
          "rice" => 0.000,
          "wheat" => 0.040,
          "gel" => 0.000
        }

        fat = %{
          "chicken" => 0.080,
          "beef" => 0.100,
          "mutton" => 0.110,
          "rice" => 0.010,
          "wheat" => 0.010,
          "gel" => 0.000
        }

        fibre = %{
          "chicken" => 0.001,
          "beef" => 0.005,
          "mutton" => 0.003,
          "rice" => 0.100,
          "wheat" => 0.150,
          "gel" => 0.000
        }

        salt = %{
          "chicken" => 0.002,
          "beef" => 0.005,
          "mutton" => 0.007,
          "rice" => 0.002,
          "wheat" => 0.008,
          "gel" => 0.000
        }

        vars = for i <- ingredients, into: %{}, do: {i, var(i, low: 0)}

        minimize lp_sum(for i <- ingredients, do: costs[i] * vars[i])

        subject_to "percentages", lp_sum(for i <- ingredients, do: vars[i]) == 100
        subject_to "protein", lp_sum(for i <- ingredients, do: protein[i] * vars[i]) >= 8.0
        subject_to "fat", lp_sum(for i <- ingredients, do: fat[i] * vars[i]) >= 6.0
        subject_to "fibre", lp_sum(for i <- ingredients, do: fibre[i] * vars[i]) <= 2.0
        subject_to "salt", lp_sum(for i <- ingredients, do: salt[i] * vars[i]) <= 0.4
      end

    {:ok, result} = ExPulp.solve(problem)
    assert result.status == :optimal
    # PuLP's known optimal cost for this problem is ~0.52
    assert_in_delta result.objective, 0.52, 0.01
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
