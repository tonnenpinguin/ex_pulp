defmodule ExPulp.MultidimVarsTest do
  use ExUnit.Case, async: true

  require ExPulp

  test "lp_vars with two dimensions" do
    problem =
      ExPulp.model "2d", :minimize do
        vars = lp_vars("x", [[:a, :b], 1..3], low: 0)

        minimize lp_sum(for a <- [:a, :b], i <- 1..3, do: vars[{a, i}])
      end

    assert Map.has_key?(problem.variables, "x_a_1")
    assert Map.has_key?(problem.variables, "x_a_2")
    assert Map.has_key?(problem.variables, "x_a_3")
    assert Map.has_key?(problem.variables, "x_b_1")
    assert Map.has_key?(problem.variables, "x_b_2")
    assert Map.has_key?(problem.variables, "x_b_3")
    assert ExPulp.Problem.num_variables(problem) == 6
  end

  test "lp_vars with three dimensions" do
    problem =
      ExPulp.model "3d", :minimize do
        vars = lp_vars("flow", [[:src1, :src2], [:dst1, :dst2], 1..2], low: 0)

        minimize lp_sum(
                   for s <- [:src1, :src2], d <- [:dst1, :dst2], t <- 1..2, do: vars[{s, d, t}]
                 )
      end

    assert Map.has_key?(problem.variables, "flow_src1_dst1_1")
    assert Map.has_key?(problem.variables, "flow_src2_dst2_2")
    assert ExPulp.Problem.num_variables(problem) == 8
  end

  test "multi-dim lp_binary_vars" do
    problem =
      ExPulp.model "2d_bin", :maximize do
        sel = lp_vars("sel", [[:a, :b], 1..2], category: :binary)

        maximize lp_sum(for a <- [:a, :b], i <- 1..2, do: sel[{a, i}])
        subject_to lp_sum(for a <- [:a, :b], i <- 1..2, do: sel[{a, i}]) <= 2
      end

    assert ExPulp.Problem.mip?(problem)
    assert ExPulp.Problem.num_variables(problem) == 4
  end

  test "multi-dim with string keys" do
    problem =
      ExPulp.model "str_2d", :minimize do
        stations = ["s1", "s2"]
        hours = ["h1", "h2", "h3"]

        power = lp_vars("pow", [stations, hours], low: 0, high: 100)

        minimize lp_sum(for s <- stations, h <- hours, do: power[{s, h}])
      end

    assert Map.has_key?(problem.variables, "pow_s1_h1")
    assert Map.has_key?(problem.variables, "pow_s2_h3")
    assert ExPulp.Problem.num_variables(problem) == 6
  end

  @tag :solver
  test "multi-dim solve: transportation problem" do
    sources = [:s1, :s2]
    destinations = [:d1, :d2]

    supply = %{s1: 30.0, s2: 50.0}
    demand = %{d1: 20.0, d2: 40.0}
    cost = %{{:s1, :d1} => 2.0, {:s1, :d2} => 4.0, {:s2, :d1} => 5.0, {:s2, :d2} => 1.0}

    {problem, vars} =
      ExPulp.model "transport", :minimize do
        flow = lp_vars("f", [sources, destinations], low: 0)

        minimize lp_sum(for s <- sources, d <- destinations, do: cost[{s, d}] * flow[{s, d}])

        # Supply constraints
        for s <- sources do
          subject_to "supply_#{s}",
                     lp_sum(for d <- destinations, do: flow[{s, d}]) <= supply[s]
        end

        # Demand constraints
        for d <- destinations do
          subject_to "demand_#{d}",
                     lp_sum(for s <- sources, do: flow[{s, d}]) >= demand[d]
        end

        %{flow: flow}
      end

    {:ok, result} = ExPulp.solve(problem)
    assert ExPulp.Result.optimal?(result)

    # Optimal: s1->d1=20, s2->d2=40 (cheapest routes), cost=2*20 + 1*40 = 80
    assert_in_delta result.objective, 80.0, 1.0e-6
    assert_in_delta ExPulp.Result.evaluate(result, vars.flow[{:s1, :d1}]), 20.0, 1.0e-6
    assert_in_delta ExPulp.Result.evaluate(result, vars.flow[{:s2, :d2}]), 40.0, 1.0e-6
  end
end
