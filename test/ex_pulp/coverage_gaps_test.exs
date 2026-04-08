defmodule ExPulp.CoverageGapsTest do
  @moduledoc """
  Tests for coverage gaps identified during code review.
  """
  use ExUnit.Case, async: true

  require ExPulp

  alias ExPulp.{Variable, Expression, Constraint, Problem, LpFormat}

  # --- Solver.Util ---

  describe "Solver.Util.parse_float/1" do
    test "parses integer string" do
      assert ExPulp.Solver.Util.parse_float("42") == 42.0
    end

    test "parses float string" do
      assert ExPulp.Solver.Util.parse_float("3.14") == 3.14
    end

    test "parses exponential notation" do
      assert ExPulp.Solver.Util.parse_float("1.5e-10") == 1.5e-10
    end

    test "returns 0.0 on empty string" do
      assert ExPulp.Solver.Util.parse_float("") == 0.0
    end

    test "returns 0.0 on garbage input" do
      assert ExPulp.Solver.Util.parse_float("not_a_number") == 0.0
    end

    test "parses negative values" do
      assert ExPulp.Solver.Util.parse_float("-7.5") == -7.5
    end
  end

  describe "Solver.Util.tmp_prefix/1" do
    test "produces unique prefixes" do
      a = ExPulp.Solver.Util.tmp_prefix("test")
      b = ExPulp.Solver.Util.tmp_prefix("test")
      assert a != b
    end

    test "includes label in path" do
      prefix = ExPulp.Solver.Util.tmp_prefix("mysolve")
      assert prefix =~ "expulp_mysolve_"
    end
  end

  describe "Solver.Util.round_integer_variables/2" do
    test "rounds integer variable within tolerance" do
      vars = %{"x" => Variable.new("x", category: :integer)}
      values = %{"x" => 3.0000001}
      result = ExPulp.Solver.Util.round_integer_variables(values, vars)
      assert result["x"] == 3.0
    end

    test "does not round integer variable outside tolerance" do
      vars = %{"x" => Variable.new("x", category: :integer)}
      values = %{"x" => 3.5}
      result = ExPulp.Solver.Util.round_integer_variables(values, vars)
      assert result["x"] == 3.5
    end

    test "does not round continuous variables" do
      vars = %{"x" => Variable.new("x")}
      values = %{"x" => 3.0000001}
      result = ExPulp.Solver.Util.round_integer_variables(values, vars)
      assert result["x"] == 3.0000001
    end

    test "handles missing variable gracefully" do
      vars = %{"x" => Variable.new("x", category: :integer)}
      values = %{}
      result = ExPulp.Solver.Util.round_integer_variables(values, vars)
      assert result == %{}
    end
  end

  # --- Problem.quadratic?/1 ---

  describe "Problem.quadratic?/1" do
    test "returns false for linear problem" do
      x = Variable.new("x", low: 0)
      problem = Problem.new("test") |> Problem.set_objective(Expression.from_variable(x))
      refute Problem.quadratic?(problem)
    end

    test "returns true for quadratic problem" do
      x = Variable.new("x", low: 0)
      quad_expr = Expression.multiply(x, x)
      problem = Problem.new("test") |> Problem.set_objective(quad_expr)
      assert Problem.quadratic?(problem)
    end

    test "returns false when no objective is set" do
      problem = Problem.new("test")
      refute Problem.quadratic?(problem)
    end
  end

  # --- Quadratic LP format output ---

  describe "quadratic LP format" do
    test "serializes quadratic objective with CPLEX convention" do
      x = Variable.new("x", low: 0)
      y = Variable.new("y", low: 0)

      # min x^2 + 2*x*y + y^2
      quad_expr =
        Expression.multiply(
          Expression.add(Expression.from_variable(x), Expression.from_variable(y)),
          Expression.add(Expression.from_variable(x), Expression.from_variable(y))
        )

      problem = Problem.new("quad") |> Problem.set_objective(quad_expr)
      lp = LpFormat.to_string(problem)

      # Should contain quadratic section with [ ... ] / 2
      assert lp =~ "[ "
      assert lp =~ "] / 2"
      # Coefficients should be doubled (CPLEX convention)
      assert lp =~ "x ^2"
      assert lp =~ "y ^2"
    end

    test "serializes mixed linear-quadratic objective" do
      x = Variable.new("x", low: 0)
      # min x^2 + 3*x
      linear = Expression.from_variable(x, 3)
      quad = Expression.multiply(x, x)
      obj = Expression.add(linear, quad)

      problem = Problem.new("mixed") |> Problem.set_objective(obj)
      lp = LpFormat.to_string(problem)

      assert lp =~ "OBJ:"
      assert lp =~ "3 x"
      assert lp =~ "[ "
      assert lp =~ "] / 2"
    end
  end

  # --- ExPulp.solve/2 validation error path ---

  describe "ExPulp.solve/2 validation" do
    test "returns error for problem without objective" do
      problem = Problem.new("empty")
      assert {:error, {:invalid_problem, reasons}} = ExPulp.solve(problem)
      assert "no objective function set" in reasons
    end
  end

  # --- add_variables first-write-wins ---

  describe "Problem.add_variable/2 first-write-wins" do
    test "keeps first registration when same name is added twice" do
      x1 = Variable.new("x", low: 0, high: 10)
      x2 = Variable.new("x", low: 5, high: 20)

      problem =
        Problem.new("test")
        |> Problem.add_variable(x1)
        |> Problem.add_variable(x2)

      assert problem.variables["x"].low == 0
      assert problem.variables["x"].high == 10
    end
  end

  # --- lp_sum with empty list ---

  describe "lp_sum/1 with empty list" do
    test "returns zero expression" do
      expr = ExPulp.DSL.Helpers.lp_sum([])
      assert expr.constant == 0.0
      assert map_size(expr.terms) == 0
    end
  end

  # --- lp_dot with mismatched lengths ---

  describe "lp_dot/2 length validation" do
    test "raises on mismatched lengths" do
      x = Variable.new("x")

      assert_raise ArgumentError, ~r/equal length/, fn ->
        ExPulp.DSL.Helpers.lp_dot([1, 2, 3], [x])
      end
    end
  end

  # --- Constraint number-sense-number guard ---

  describe "Constraint number-sense-number" do
    test "raises when both sides are numbers" do
      assert_raise ArgumentError, ~r/cannot create a constraint between two numbers/, fn ->
        Constraint.leq(3, 5)
      end
    end

    test "raises for geq with two numbers" do
      assert_raise ArgumentError, ~r/cannot create a constraint between two numbers/, fn ->
        Constraint.geq(3, 5)
      end
    end

    test "raises for eq with two numbers" do
      assert_raise ArgumentError, ~r/cannot create a constraint between two numbers/, fn ->
        Constraint.eq(3, 5)
      end
    end
  end

  # --- DSL builder cleanup on exception ---

  describe "DSL builder cleanup on exception" do
    test "cleans up process dictionary on exception, allowing subsequent model calls" do
      assert_raise RuntimeError, "boom", fn ->
        ExPulp.model "crash", :minimize do
          x = var(low: 0)
          minimize x
          raise "boom"
        end
      end

      # The process dictionary should be cleaned up, so this should work
      problem =
        ExPulp.model "after_crash", :minimize do
          x = var(low: 0)
          minimize x
          subject_to x >= 1
        end

      assert problem.name == "after_crash"
    end
  end

  # --- Problem name sanitization alignment ---

  describe "Problem name sanitization" do
    test "sanitizes special characters same as Variable" do
      problem = Problem.new("my-problem[1]")
      assert problem.name == "my_problem_1_"
    end

    test "sanitizes slashes and arrows" do
      problem = Problem.new("a->b/c")
      assert problem.name == "a__b_c"
    end
  end

  # --- Result.feasible?/1 with new :feasible status ---

  describe "Result.feasible?/1" do
    test "returns true for :optimal" do
      result = %ExPulp.Result{status: :optimal, objective: 5.0, variables: %{}}
      assert ExPulp.Result.feasible?(result)
    end

    test "returns true for :feasible" do
      result = %ExPulp.Result{status: :feasible, objective: 5.0, variables: %{"x" => 3.0}}
      assert ExPulp.Result.feasible?(result)
    end

    test "returns false for :infeasible" do
      result = %ExPulp.Result{status: :infeasible}
      refute ExPulp.Result.feasible?(result)
    end

    test "returns false for :not_solved" do
      result = %ExPulp.Result{status: :not_solved}
      refute ExPulp.Result.feasible?(result)
    end

    test "returns false for :unbounded" do
      result = %ExPulp.Result{status: :unbounded}
      refute ExPulp.Result.feasible?(result)
    end
  end

  # --- constraints_ordered/1 ---

  describe "Problem.constraints_ordered/1" do
    test "returns constraints in insertion order" do
      x = Variable.new("x", low: 0)
      y = Variable.new("y", low: 0)

      problem =
        Problem.new("test")
        |> Problem.set_objective(Expression.from_variable(x))
        |> Problem.add_constraint(Constraint.geq(Expression.from_variable(x), 1), "first")
        |> Problem.add_constraint(Constraint.leq(Expression.from_variable(y), 10), "second")
        |> Problem.add_constraint(Constraint.eq(Expression.from_variable(x), 5), "third")

      names = Problem.constraints_ordered(problem) |> Enum.map(fn {name, _} -> name end)
      assert names == ["first", "second", "third"]
    end
  end
end
