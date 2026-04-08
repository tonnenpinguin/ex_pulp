defmodule ExPulp.InspectTest do
  use ExUnit.Case, async: true

  alias ExPulp.{Variable, Expression, Constraint, Problem, Result}

  describe "Variable inspect" do
    test "bounded variable" do
      var = Variable.new("x", low: 0, high: 10)
      assert inspect(var) == "#Variable<0 <= x <= 10>"
    end

    test "free variable" do
      var = Variable.new("x")
      assert inspect(var) == "#Variable<x free>"
    end

    test "lower-bounded only" do
      var = Variable.new("x", low: 0)
      assert inspect(var) == "#Variable<0 <= x>"
    end

    test "upper-bounded only" do
      var = Variable.new("x", high: 10)
      assert inspect(var) == "#Variable<x <= 10>"
    end

    test "fixed variable" do
      var = Variable.new("x", low: 5, high: 5)
      assert inspect(var) == "#Variable<x = 5>"
    end

    test "integer variable" do
      var = Variable.new("x", low: 0, high: 100, category: :integer)
      assert inspect(var) == "#Variable<0 <= x <= 100, integer>"
    end

    test "binary variable" do
      var = Variable.new("x", category: :binary)
      assert inspect(var) == "#Variable<0 <= x <= 1, binary>"
    end
  end

  describe "Expression inspect" do
    test "simple expression" do
      x = Variable.new("x")
      expr = Expression.new([{x, 2}])
      assert inspect(expr) == "#Expression<2*x>"
    end

    test "multi-variable expression" do
      x = Variable.new("x")
      y = Variable.new("y")
      expr = Expression.new([{x, 2}, {y, -3}], 5.0)
      assert inspect(expr) == "#Expression<2*x - 3*y + 5>"
    end

    test "empty expression" do
      expr = Expression.new()
      assert inspect(expr) == "#Expression<0>"
    end

    test "constant-only expression" do
      expr = Expression.new([], 42.0)
      assert inspect(expr) == "#Expression<42>"
    end

    test "coefficient 1 is omitted" do
      x = Variable.new("x")
      expr = Expression.from_variable(x)
      assert inspect(expr) == "#Expression<x>"
    end

    test "coefficient -1 shows minus" do
      x = Variable.new("x")
      expr = Expression.negate(Expression.from_variable(x))
      assert inspect(expr) == "#Expression<-x>"
    end
  end

  describe "Constraint inspect" do
    test "geq constraint" do
      x = Variable.new("x")
      c = Constraint.geq(Expression.from_variable(x), 5)
      assert inspect(c) == "#Constraint<x >= 5>"
    end

    test "leq constraint" do
      x = Variable.new("x")
      y = Variable.new("y")
      c = Constraint.leq(Expression.new([{x, 2}, {y, 3}]), 10)
      assert inspect(c) == "#Constraint<2*x + 3*y <= 10>"
    end

    test "eq constraint" do
      x = Variable.new("x")
      c = Constraint.eq(Expression.from_variable(x), 0)
      assert inspect(c) == "#Constraint<x = 0>"
    end
  end

  describe "Problem inspect" do
    test "LP problem" do
      x = Variable.new("x", low: 0)
      y = Variable.new("y", low: 0)

      problem =
        Problem.new("test", :minimize)
        |> Problem.set_objective(Expression.new([{x, 1}, {y, 1}]))
        |> Problem.add_constraint(Constraint.geq(Expression.new([{x, 1}, {y, 1}]), 5), "c1")

      assert inspect(problem) == "#Problem<\"test\" minimize LP, 2 vars, 1 constraints>"
    end

    test "MIP problem" do
      x = Variable.new("x", low: 0, category: :integer)

      problem =
        Problem.new("mip", :maximize)
        |> Problem.set_objective(Expression.from_variable(x))

      assert inspect(problem) == "#Problem<\"mip\" maximize MIP, 1 vars, 0 constraints>"
    end
  end

  describe "Result inspect" do
    test "optimal result" do
      result = %Result{status: :optimal, objective: 5.0, variables: %{"x" => 3.0, "y" => 2.0}}
      assert inspect(result) == "#Result<optimal, objective: 5.0, 2 variables>"
    end

    test "infeasible result" do
      result = %Result{status: :infeasible}
      assert inspect(result) == "#Result<infeasible, 0 variables>"
    end
  end
end
