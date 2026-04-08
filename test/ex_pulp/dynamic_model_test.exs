defmodule ExPulp.DynamicModelTest do
  use ExUnit.Case

  require ExPulp

  @tag :solver
  test "for loop with subject_to inside model block" do
    items = [1, 2, 3]
    capacities = %{1 => 10.0, 2 => 20.0, 3 => 30.0}

    problem = ExPulp.model "dynamic", :minimize do
      vars =
        for i <- items, into: %{} do
          {i, var("x_#{i}", low: 0)}
        end

      minimize lp_sum(for i <- items, do: vars[i])

      for i <- items do
        subject_to "cap_#{i}", vars[i] <= capacities[i]
      end

      for i <- items do
        subject_to vars[i] >= 1
      end
    end

    assert ExPulp.Problem.num_constraints(problem) == 6

    {:ok, result} = ExPulp.solve(problem)
    assert ExPulp.Result.optimal?(result)
    assert_in_delta result.variables["x_1"], 1.0, 1.0e-6
  end

  @tag :solver
  test "nested if inside for with subject_to" do
    problem = ExPulp.model "conditional", :minimize do
      items = [1, 2, 3, 4, 5]

      vars =
        for i <- items, into: %{} do
          {i, var("x_#{i}", low: 0)}
        end

      minimize lp_sum(for i <- items, do: vars[i])

      for i <- items do
        if rem(i, 2) == 0 do
          subject_to "even_#{i}", vars[i] >= 10
        else
          subject_to "odd_#{i}", vars[i] >= 1
        end
      end
    end

    {:ok, result} = ExPulp.solve(problem)
    assert ExPulp.Result.optimal?(result)
    # Even items (2, 4) are >= 10, odd items (1, 3, 5) are >= 1
    assert_in_delta result.variables["x_1"], 1.0, 1.0e-6
    assert_in_delta result.variables["x_2"], 10.0, 1.0e-6
  end

  @tag :solver
  test "add_to_objective builds objective incrementally" do
    problem = ExPulp.model "incremental", :minimize do
      x = var(low: 0, high: 10)
      y = var(low: 0, high: 10)

      # Build objective across multiple add_to_objective calls
      add_to_objective 2 * x
      add_to_objective 3 * y

      subject_to "lb", x + y >= 5
    end

    {:ok, result} = ExPulp.solve(problem)
    assert ExPulp.Result.optimal?(result)
    # Minimize 2x + 3y s.t. x+y >= 5: optimal is x=5, y=0 (cost=10)
    assert_in_delta result.variables["x"], 5.0, 1.0e-6
    assert_in_delta result.variables["y"], 0.0, 1.0e-6
  end

  @tag :solver
  test "add_to_objective from for loops" do
    costs = %{1 => 1.0, 2 => 5.0, 3 => 10.0}

    problem = ExPulp.model "loop_obj", :minimize do
      vars = lp_vars("x", 1..3, low: 0)

      for i <- 1..3 do
        add_to_objective costs[i] * vars[i]
        subject_to vars[i] >= 1
      end
    end

    {:ok, result} = ExPulp.solve(problem)
    assert ExPulp.Result.optimal?(result)
    # Each var at minimum 1.0
    assert_in_delta result.objective, 16.0, 1.0e-6
  end

  @tag :solver
  test "Result.evaluate with expression" do
    problem = ExPulp.model "eval", :minimize do
      x = var(low: 0, high: 10)
      y = var(low: 0, high: 10)

      minimize x + y
      subject_to x + y >= 5
    end

    {:ok, result} = ExPulp.solve(problem)

    # Evaluate an expression against the result
    x = ExPulp.Variable.new("x")
    y = ExPulp.Variable.new("y")
    expr = ExPulp.Expression.new([{x, 2}, {y, 3}])
    val = ExPulp.Result.evaluate(result, expr)
    assert is_float(val)
  end

  @tag :solver
  test "EV charging mini-model pattern" do
    # Simplified version of the PoC pattern:
    # 2 chargepoints × 3 time slots, binary on/off, min/max power
    chargepoints = [:cp1, :cp2]
    slots = [1, 2, 3]
    min_power = 3.0
    max_power = 11.0
    target_kwh = %{cp1: 5.0, cp2: 3.0}
    pool_max = 15.0
    prices = %{1 => 10.0, 2 => 20.0, 3 => 15.0}
    slot_hours = 0.25

    problem = ExPulp.model "ev_mini", :minimize do
      # Decision variables
      power =
        for cp <- chargepoints, s <- slots, into: %{} do
          {{cp, s}, var("p_#{cp}_#{s}", low: 0)}
        end

      on =
        for cp <- chargepoints, s <- slots, into: %{} do
          {{cp, s}, var("on_#{cp}_#{s}", category: :binary)}
        end

      shortfall =
        for cp <- chargepoints, into: %{} do
          {cp, var("sf_#{cp}", low: 0)}
        end

      # Objective: minimize electricity cost + shortfall penalty
      cost =
        lp_sum(
          for cp <- chargepoints, s <- slots do
            prices[s] * slot_hours * power[{cp, s}]
          end
        )

      penalty = lp_sum(for {_cp, sf} <- shortfall, do: 500.0 * sf)

      minimize cost + penalty

      # Big-M constraints: power linked to on/off
      for cp <- chargepoints, s <- slots do
        subject_to power[{cp, s}] >= min_power * on[{cp, s}]
        subject_to power[{cp, s}] <= max_power * on[{cp, s}]
      end

      # Energy delivery
      for cp <- chargepoints do
        energy = lp_sum(for s <- slots, do: slot_hours * power[{cp, s}])
        subject_to energy + shortfall[cp] >= target_kwh[cp]
      end

      # Pool power limit per slot
      for s <- slots do
        pool = lp_sum(for cp <- chargepoints, do: power[{cp, s}])
        subject_to pool <= pool_max
      end
    end

    {:ok, result} = ExPulp.solve(problem)
    assert ExPulp.Result.optimal?(result)

    # All chargepoints should get enough energy (shortfall near zero)
    assert_in_delta result.variables["sf_cp1"] || 0, 0.0, 1.0
    assert_in_delta result.variables["sf_cp2"] || 0, 0.0, 1.0
  end
end
