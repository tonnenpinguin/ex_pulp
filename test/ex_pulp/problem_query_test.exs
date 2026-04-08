defmodule ExPulp.ProblemQueryTest do
  use ExUnit.Case, async: true

  alias ExPulp.{Variable, Expression, Constraint, Problem}

  setup do
    x = Variable.new("x", low: 0, high: 10)
    y = Variable.new("y", low: 0, high: 10)

    problem =
      Problem.new("test", :minimize)
      |> Problem.set_objective(Expression.new([{x, 1}, {y, 1}]))
      |> Problem.add_constraint(Constraint.geq(Expression.new([{x, 1}, {y, 1}]), 5), "sum_ge_5")
      |> Problem.add_constraint(Constraint.leq(Expression.from_variable(x), 8), "x_le_8")

    %{problem: problem}
  end

  test "num_variables/1", %{problem: p} do
    assert Problem.num_variables(p) == 2
  end

  test "num_constraints/1", %{problem: p} do
    assert Problem.num_constraints(p) == 2
  end

  test "get_constraint/2 found", %{problem: p} do
    assert {:ok, %Constraint{sense: :geq}} = Problem.get_constraint(p, "sum_ge_5")
  end

  test "get_constraint/2 not found", %{problem: p} do
    assert :error = Problem.get_constraint(p, "nonexistent")
  end

  test "has_constraint?/2", %{problem: p} do
    assert Problem.has_constraint?(p, "sum_ge_5")
    assert Problem.has_constraint?(p, "x_le_8")
    refute Problem.has_constraint?(p, "nope")
  end

  test "constraint_names/1", %{problem: p} do
    assert Problem.constraint_names(p) == ["sum_ge_5", "x_le_8"]
  end

  describe "validate/1" do
    test "valid problem passes", %{problem: p} do
      assert {:ok, ^p} = Problem.validate(p)
    end

    test "missing objective fails" do
      problem = Problem.new("test")
      assert {:error, reasons} = Problem.validate(problem)
      assert "no objective function set" in reasons
    end

    test "duplicate constraint names fail" do
      x = Variable.new("x", low: 0)

      problem =
        Problem.new("test")
        |> Problem.set_objective(Expression.from_variable(x))

      # Manually insert duplicate constraint names
      c = Constraint.geq(Expression.from_variable(x), 1)
      problem = %{problem | constraints: [{"dup", c}, {"dup", c}]}

      assert {:error, reasons} = Problem.validate(problem)
      assert Enum.any?(reasons, &String.contains?(&1, "duplicate"))
    end
  end
end
