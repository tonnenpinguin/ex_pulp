defmodule ExPulp.DSLTest do
  use ExUnit.Case, async: true

  require ExPulp

  test "model macro builds a problem" do
    problem = ExPulp.model "test", :minimize do
      x = var(low: 0, high: 10)
      y = var(low: 0, high: 10)

      minimize x + y
      subject_to "sum_ge_5", x + y >= 5
    end

    assert %ExPulp.Problem{} = problem
    assert problem.name == "test"
    assert problem.sense == :minimize
    assert problem.objective != nil
    assert length(problem.constraints) == 1
  end

  test "auto-deduce variable name from LHS" do
    problem = ExPulp.model "auto_name", :minimize do
      my_var = var(low: 0, high: 10)
      minimize my_var
    end

    assert Map.has_key?(problem.variables, "my_var")
  end

  test "explicit name string still works" do
    problem = ExPulp.model "explicit", :minimize do
      x = var("custom_name", low: 0)
      minimize x
    end

    assert Map.has_key?(problem.variables, "custom_name")
  end

  test "name keyword overrides auto-deduced name" do
    problem = ExPulp.model "override", :minimize do
      x = var(name: "overridden", low: 0, high: 10)
      minimize x
    end

    assert Map.has_key?(problem.variables, "overridden")
    refute Map.has_key?(problem.variables, "x")
  end

  test "var with no options auto-deduces name" do
    problem = ExPulp.model "bare", :minimize do
      x = var()
      minimize x
    end

    assert Map.has_key?(problem.variables, "x")
  end

  test "arithmetic operators work on variables" do
    problem = ExPulp.model "arith", :minimize do
      x = var(low: 0)
      y = var(low: 0)

      minimize 2 * x + 3 * y
      subject_to "c1", x + y >= 10
      subject_to "c2", x - y <= 5
    end

    assert problem.objective.terms |> map_size() == 2
    assert length(problem.constraints) == 2
  end

  test "plain number arithmetic still works inside model" do
    problem = ExPulp.model "numbers", :minimize do
      cost = 2 + 3
      x = var(low: 0, high: cost)

      minimize x
    end

    assert Map.values(problem.variables) |> hd() |> Map.get(:high) == 5
  end

  test "unary minus on variable" do
    problem = ExPulp.model "neg", :maximize do
      x = var(low: 0, high: 10)

      maximize -x
      subject_to "c1", x >= 1
    end

    [var] = ExPulp.Expression.sorted_variables(problem.objective)
    assert problem.objective.terms[var] == -1
  end

  test "division by scalar" do
    problem = ExPulp.model "div", :minimize do
      x = var(low: 0, high: 100)

      minimize x / 2
    end

    [var] = ExPulp.Expression.sorted_variables(problem.objective)
    assert problem.objective.terms[var] == 0.5
  end

  test "lp_sum with comprehension" do
    problem = ExPulp.model "sum", :minimize do
      names = ["a", "b", "c"]
      vars = for n <- names, do: var(n, low: 0)

      minimize lp_sum(vars)
      subject_to "total", lp_sum(vars) >= 10
    end

    assert map_size(problem.objective.terms) == 3
  end

  test "lp_dot with coefficients" do
    problem = ExPulp.model "dot", :minimize do
      x = var(low: 0)
      y = var(low: 0)

      minimize lp_dot([0.5, 0.3], [x, y])
    end

    vars = ExPulp.Expression.sorted_variables(problem.objective)
    coeffs = Enum.map(vars, &problem.objective.terms[&1])
    assert coeffs == [0.5, 0.3]
  end

  test "subject_to without name auto-generates" do
    problem = ExPulp.model "auto", :minimize do
      x = var(low: 0)
      minimize x
      subject_to x >= 1
      subject_to x <= 10
    end

    assert [{"_C1", _}, {"_C2", _}] = problem.constraints
  end

  test "maximize sense" do
    problem = ExPulp.model "max", :maximize do
      x = var(low: 0, high: 10)
      maximize x
    end

    assert problem.sense == :maximize
  end

  test "equality constraint" do
    problem = ExPulp.model "eq", :minimize do
      x = var(low: 0)
      y = var(low: 0)

      minimize x + y
      subject_to "eq", x + y == 10
    end

    {_, constraint} = hd(problem.constraints)
    assert constraint.sense == :eq
  end

  test "compound expression: 2*x + 3*y - 1 >= 5" do
    problem = ExPulp.model "compound", :minimize do
      x = var(low: 0)
      y = var(low: 0)

      minimize x
      subject_to "c1", 2 * x + 3 * y - 1 >= 5
    end

    {_, c} = hd(problem.constraints)
    assert c.sense == :geq
  end

  test "integer and binary variables" do
    problem = ExPulp.model "mip", :minimize do
      x = var(low: 0, high: 100, category: :integer)
      y = var(category: :binary)

      minimize x + y
      subject_to x + y >= 1
    end

    vars = problem.variables
    assert vars["x"].category == :integer
    assert vars["y"].category == :integer
    assert vars["y"].low == 0
    assert vars["y"].high == 1
  end
end
