defmodule ExPulp.QuadraticSolveTest do
  use ExUnit.Case

  require ExPulp

  @moduletag :solver

  test "simple QP: minimize x^2 + y^2 s.t. x + y >= 1" do
    problem = ExPulp.model "qp_simple", :minimize do
      x = var(low: 0, high: 10)
      y = var(low: 0, high: 10)

      minimize x * x + y * y
      subject_to "sum", x + y >= 1
    end

    {:ok, result} = ExPulp.solve(problem)
    assert ExPulp.Result.optimal?(result)
    assert_in_delta result.variables["x"], 0.5, 1.0e-4
    assert_in_delta result.variables["y"], 0.5, 1.0e-4
    assert_in_delta result.objective, 0.5, 1.0e-4
  end

  test "QP with linear + quadratic objective" do
    problem = ExPulp.model "qp_mixed", :minimize do
      x = var(low: 0, high: 10)
      y = var(low: 0, high: 10)

      minimize x * x + y * y + x + y
      subject_to "sum", x + y >= 2
    end

    {:ok, result} = ExPulp.solve(problem)
    assert ExPulp.Result.optimal?(result)
    assert_in_delta result.variables["x"], 1.0, 1.0e-4
    assert_in_delta result.variables["y"], 1.0, 1.0e-4
  end

  test "QP with cross terms" do
    problem = ExPulp.model "qp_cross", :minimize do
      x = var(low: 0, high: 10)
      y = var(low: 0, high: 10)

      minimize x * x + x * y + y * y
      subject_to "sum", x + y >= 1
    end

    {:ok, result} = ExPulp.solve(problem)
    assert ExPulp.Result.optimal?(result)
    # Symmetric minimum at x = y = 0.5
    assert_in_delta result.variables["x"], 0.5, 1.0e-3
    assert_in_delta result.variables["y"], 0.5, 1.0e-3
  end

  test "CBC rejects quadratic problems" do
    problem = ExPulp.model "qp_cbc", :minimize do
      x = var(low: 0, high: 10)
      minimize x * x
      subject_to x >= 1
    end

    assert {:error, :quadratic_not_supported} =
             ExPulp.solve(problem, solver: ExPulp.Solver.CBC)
  end

  test "DSL: (x + y)^2 distributes correctly" do
    problem = ExPulp.model "qp_square", :minimize do
      x = var(low: 0, high: 10)
      y = var(low: 0, high: 10)

      minimize (x + y) * (x + y)
      subject_to x + y >= 2
    end

    {:ok, result} = ExPulp.solve(problem)
    assert ExPulp.Result.optimal?(result)
    # (x+y)^2 minimized at x+y=2, so objective = 4
    assert_in_delta result.objective, 4.0, 1.0e-4
  end

  test "QP with scaled quadratic: minimize 0.5*x^2" do
    problem = ExPulp.model "qp_scaled", :minimize do
      x = var(low: -10, high: 10)

      minimize 0.5 * x * x
      subject_to x >= 3
    end

    {:ok, result} = ExPulp.solve(problem)
    assert ExPulp.Result.optimal?(result)
    assert_in_delta result.variables["x"], 3.0, 1.0e-4
    assert_in_delta result.objective, 4.5, 1.0e-4
  end
end
