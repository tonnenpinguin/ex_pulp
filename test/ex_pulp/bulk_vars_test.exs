defmodule ExPulp.BulkVarsTest do
  use ExUnit.Case, async: true

  require ExPulp

  describe "lp_vars in DSL" do
    test "creates indexed variable map with range" do
      problem =
        ExPulp.model "bulk", :minimize do
          vars = lp_vars("x", 1..3, low: 0, high: 10)

          minimize lp_sum(for i <- 1..3, do: vars[i])
        end

      assert Map.has_key?(problem.variables, "x_1")
      assert Map.has_key?(problem.variables, "x_2")
      assert Map.has_key?(problem.variables, "x_3")
      assert map_size(problem.objective.terms) == 3
    end

    test "creates indexed variable map with string keys" do
      problem =
        ExPulp.model "bulk_str", :minimize do
          items = ["a", "b", "c"]
          vars = lp_vars("item", items, low: 0)

          minimize lp_sum(for i <- items, do: vars[i])
        end

      assert Map.has_key?(problem.variables, "item_a")
      assert Map.has_key?(problem.variables, "item_b")
      assert Map.has_key?(problem.variables, "item_c")
    end

    test "lp_binary_vars creates binary variables" do
      problem =
        ExPulp.model "binary_bulk", :maximize do
          sel = lp_binary_vars("select", 1..3)

          maximize lp_sum(for i <- 1..3, do: sel[i])
          subject_to "limit", lp_sum(for i <- 1..3, do: sel[i]) <= 2
        end

      vars = problem.variables
      assert vars["select_1"].category == :integer
      assert vars["select_1"].low == 0
      assert vars["select_1"].high == 1
    end

    test "lp_integer_vars creates integer variables" do
      problem =
        ExPulp.model "int_bulk", :minimize do
          quantities = lp_integer_vars("qty", 1..3, low: 0, high: 100)

          minimize lp_sum(for i <- 1..3, do: quantities[i])
        end

      assert problem.variables["qty_1"].category == :integer
    end
  end

  describe "for_each in DSL" do
    test "for_each with prefix creates named constraints" do
      problem =
        ExPulp.model "foreach", :minimize do
          vars = lp_vars("x", 1..3, low: 0, high: 100)
          caps = %{1 => 10, 2 => 20, 3 => 30}

          minimize lp_sum(for i <- 1..3, do: vars[i])
          for_each 1..3, "cap", fn i -> vars[i] <= caps[i] end
        end

      assert ExPulp.Problem.has_constraint?(problem, "cap_1")
      assert ExPulp.Problem.has_constraint?(problem, "cap_2")
      assert ExPulp.Problem.has_constraint?(problem, "cap_3")
      assert ExPulp.Problem.num_constraints(problem) == 3
    end

    test "for_each without prefix auto-names" do
      problem =
        ExPulp.model "foreach_auto", :minimize do
          vars = lp_vars("x", 1..3, low: 0)

          minimize lp_sum(for i <- 1..3, do: vars[i])
          for_each 1..3, fn i -> vars[i] >= 1 end
        end

      assert ExPulp.Problem.num_constraints(problem) == 3
    end
  end

  @tag :solver
  test "for_each end-to-end solve" do
    problem =
      ExPulp.model "foreach_solve", :minimize do
        vars = lp_vars("x", 1..3, low: 0)
        costs = %{1 => 1.0, 2 => 2.0, 3 => 3.0}
        demands = %{1 => 5.0, 2 => 10.0, 3 => 15.0}

        minimize lp_sum(for i <- 1..3, do: costs[i] * vars[i])
        for_each 1..3, "demand", fn i -> vars[i] >= demands[i] end
      end

    {:ok, result} = ExPulp.solve(problem)
    assert ExPulp.Result.optimal?(result)
    # Optimal: each var at its minimum demand
    assert_in_delta result.variables["x_1"], 5.0, 1.0e-6
    assert_in_delta result.variables["x_2"], 10.0, 1.0e-6
    assert_in_delta result.variables["x_3"], 15.0, 1.0e-6
  end
end
