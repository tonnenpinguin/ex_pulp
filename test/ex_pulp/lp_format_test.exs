defmodule ExPulp.LpFormatTest do
  use ExUnit.Case, async: true

  alias ExPulp.{Variable, Expression, Constraint, Problem, LpFormat}

  test "simple minimization problem" do
    x = Variable.new("x", low: 0, high: 10)
    y = Variable.new("y", low: 0, high: 10)

    problem =
      Problem.new("test", :minimize)
      |> Problem.set_objective(Expression.new([{x, 1}, {y, 1}]))
      |> Problem.add_constraint(Constraint.geq(Expression.new([{x, 1}, {y, 1}]), 5), "c1")

    lp = LpFormat.to_string(problem)

    assert lp =~ "\\* test *\\"
    assert lp =~ "Minimize"
    assert lp =~ "OBJ:"
    assert lp =~ "Subject To"
    assert lp =~ "c1:"
    assert lp =~ ">= 5"
    assert lp =~ "Bounds"
    assert lp =~ "End"
  end

  test "maximization sense" do
    x = Variable.new("x", low: 0, high: 10)

    problem =
      Problem.new("test", :maximize)
      |> Problem.set_objective(Expression.from_variable(x))

    lp = LpFormat.to_string(problem)
    assert lp =~ "Maximize"
  end

  test "coefficient formatting" do
    x = Variable.new("x", low: 0)
    y = Variable.new("y", low: 0)
    z = Variable.new("z", low: 0)

    # coeff 1 omitted, coeff -1 as "- var", others shown
    expr = Expression.new([{x, 1}, {y, -1}, {z, 2.5}])

    problem =
      Problem.new("test", :minimize)
      |> Problem.set_objective(expr)

    lp = LpFormat.to_string(problem)
    # x should appear without coefficient
    assert lp =~ ~r/OBJ:.*\bx\b/
    # y should have minus
    assert lp =~ ~r/- y\b/
    # z should have 2.5
    assert lp =~ ~r/2\.5 z\b/
  end

  test "default-positive continuous vars omitted from bounds" do
    x = Variable.new("x", low: 0)

    problem =
      Problem.new("test", :minimize)
      |> Problem.set_objective(Expression.from_variable(x))

    lp = LpFormat.to_string(problem)
    # No Bounds section needed for default-positive var
    refute lp =~ "Bounds"
  end

  test "bounded variable appears in bounds" do
    x = Variable.new("x", low: 0, high: 10)

    problem =
      Problem.new("test", :minimize)
      |> Problem.set_objective(Expression.from_variable(x))

    lp = LpFormat.to_string(problem)
    assert lp =~ "Bounds"
    assert lp =~ ~r/0.*<=.*x.*<=.*10/
  end

  test "free variable" do
    x = Variable.new("x")

    problem =
      Problem.new("test", :minimize)
      |> Problem.set_objective(Expression.from_variable(x))

    lp = LpFormat.to_string(problem)
    assert lp =~ "x free"
  end

  test "integer variables in Generals section" do
    x = Variable.new("x", low: 0, high: 100, category: :integer)

    problem =
      Problem.new("test", :minimize)
      |> Problem.set_objective(Expression.from_variable(x))

    lp = LpFormat.to_string(problem)
    assert lp =~ "Generals"
    assert lp =~ " x\n"
  end

  test "binary variables in Binaries section" do
    x = Variable.new("x", category: :binary)

    problem =
      Problem.new("test", :minimize)
      |> Problem.set_objective(Expression.from_variable(x))

    lp = LpFormat.to_string(problem)
    assert lp =~ "Binaries"
    assert lp =~ " x\n"
    # Binary vars should NOT appear in Bounds
    refute lp =~ "Bounds"
  end

  test "constraint with expression constant adjusts RHS" do
    x = Variable.new("x", low: 0)
    # x + 3 <= 10  =>  in LP: x <= 7
    expr = Expression.new([{x, 1}], 3.0)
    c = Constraint.leq(expr, 10)

    problem =
      Problem.new("test", :minimize)
      |> Problem.set_objective(Expression.from_variable(x))
      |> Problem.add_constraint(c, "c1")

    lp = LpFormat.to_string(problem)
    assert lp =~ "<= 7"
  end

  test "equality constraint" do
    x = Variable.new("x", low: 0)
    c = Constraint.eq(Expression.from_variable(x), 5)

    problem =
      Problem.new("test", :minimize)
      |> Problem.set_objective(Expression.from_variable(x))
      |> Problem.add_constraint(c, "fix")

    lp = LpFormat.to_string(problem)
    assert lp =~ "fix:"
    assert lp =~ "= 5"
  end

  test "no constraints produces no Subject To section" do
    x = Variable.new("x", low: 0)

    problem =
      Problem.new("test", :minimize)
      |> Problem.set_objective(Expression.from_variable(x))

    lp = LpFormat.to_string(problem)
    refute lp =~ "Subject To"
  end
end
