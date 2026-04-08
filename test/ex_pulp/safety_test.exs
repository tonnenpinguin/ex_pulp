defmodule ExPulp.SafetyTest do
  use ExUnit.Case, async: true

  require ExPulp

  alias ExPulp.{Variable, Expression, Problem, Constraint}

  describe "nested model blocks" do
    test "raises when nesting model blocks" do
      assert_raise RuntimeError, ~r/cannot be nested/, fn ->
        ExPulp.model "outer", :minimize do
          x = var(low: 0)
          minimize x

          _inner =
            ExPulp.model "inner", :maximize do
              y = var(low: 0)
              maximize y
            end
        end
      end
    end
  end

  describe "invalid variable category" do
    test "raises on typo in category" do
      assert_raise ArgumentError, ~r/invalid category/, fn ->
        Variable.new("x", category: :binray)
      end
    end

    test "raises on unknown category" do
      assert_raise ArgumentError, ~r/invalid category/, fn ->
        Variable.new("x", category: :float)
      end
    end

    test "valid categories work" do
      assert %Variable{category: :continuous} = Variable.new("a")
      assert %Variable{category: :integer} = Variable.new("b", category: :integer)
      assert %Variable{category: :integer} = Variable.new("c", category: :binary)
    end
  end

  describe "divide by zero" do
    test "raises ArgumentError" do
      x = Variable.new("x")
      expr = Expression.from_variable(x)

      assert_raise ArgumentError, ~r/cannot divide.*zero/, fn ->
        Expression.divide(expr, 0)
      end
    end

    test "raises for 0.0" do
      x = Variable.new("x")

      assert_raise ArgumentError, ~r/cannot divide.*zero/, fn ->
        Expression.divide(x, 0.0)
      end
    end
  end

  describe "minimize/maximize sense mismatch" do
    test "maximize inside :minimize model raises" do
      assert_raise ArgumentError, ~r/maximize.*:minimize/, fn ->
        ExPulp.model "bad", :minimize do
          x = var(low: 0)
          maximize x
        end
      end
    end

    test "minimize inside :maximize model raises" do
      assert_raise ArgumentError, ~r/minimize.*:maximize/, fn ->
        ExPulp.model "bad", :maximize do
          x = var(low: 0)
          minimize x
        end
      end
    end

    test "matching sense works" do
      problem =
        ExPulp.model "ok", :minimize do
          x = var(low: 0)
          minimize x
        end

      assert problem.sense == :minimize

      problem =
        ExPulp.model "ok2", :maximize do
          x = var(low: 0, high: 10)
          maximize x
        end

      assert problem.sense == :maximize
    end
  end

  describe "quadratic variable registration" do
    test "quad-only objective registers variables" do
      problem =
        ExPulp.model "quad_reg", :minimize do
          x = var(low: 0, high: 10)

          minimize x * x
          subject_to x >= 1
        end

      assert Map.has_key?(problem.variables, "x")
    end

    @tag :solver
    test "quad-only objective solves correctly" do
      problem =
        ExPulp.model "quad_solve", :minimize do
          x = var(low: 0, high: 10)

          minimize x * x
          subject_to x >= 3
        end

      {:ok, result} = ExPulp.solve(problem)
      assert ExPulp.Result.optimal?(result)
      assert_in_delta result.variables["x"], 3.0, 1.0e-4
    end
  end

  describe "lp_weighted_sum with mismatched keys" do
    test "ignores keys present only in coefficients" do
      x = Variable.new("x")
      vars = %{a: x}
      coeffs = %{a: 2, b: 3}

      expr = ExPulp.DSL.Helpers.lp_weighted_sum(coeffs, vars)
      assert Expression.to_string(expr) == "2*x"
    end

    test "ignores keys present only in variables" do
      x = Variable.new("x")
      y = Variable.new("y")
      vars = %{a: x, b: y}
      coeffs = %{a: 5}

      expr = ExPulp.DSL.Helpers.lp_weighted_sum(coeffs, vars)
      assert Expression.to_string(expr) == "5*x"
    end

    test "empty intersection produces zero expression" do
      x = Variable.new("x")
      vars = %{a: x}
      coeffs = %{b: 3}

      expr = ExPulp.DSL.Helpers.lp_weighted_sum(coeffs, vars)
      assert Expression.to_string(expr) == "0"
    end
  end

  describe "Problem.validate/1 edge cases" do
    test "catches unregistered variables" do
      # Build a problem with a variable in a constraint that isn't registered
      x = Variable.new("x", low: 0)
      y = Variable.new("y", low: 0)

      problem = %Problem{
        name: "test",
        sense: :minimize,
        objective: Expression.from_variable(x),
        constraints: [{"c1", Constraint.geq(Expression.from_variable(y), 1)}],
        variables: %{"x" => x}
      }

      assert {:error, reasons} = Problem.validate(problem)
      assert Enum.any?(reasons, &String.contains?(&1, "unregistered"))
    end
  end
end
