defmodule ExPulp.ModelReturnTest do
  use ExUnit.Case

  require ExPulp

  test "model returns just problem when last expr is DSL form" do
    result =
      ExPulp.model "plain", :minimize do
        x = var(low: 0, high: 10)
        minimize x
        subject_to x >= 3
      end

    assert %ExPulp.Problem{} = result
  end

  test "model returns {problem, map} when last expr is a map" do
    {problem, vars} =
      ExPulp.model "with_vars", :minimize do
        x = var(low: 0, high: 10)
        y = var(low: 0, high: 10)
        minimize x + y
        subject_to x + y >= 5
        %{x: x, y: y}
      end

    assert %ExPulp.Problem{} = problem
    assert %ExPulp.Variable{name: "x"} = vars.x
    assert %ExPulp.Variable{name: "y"} = vars.y
  end

  test "model returns {problem, tuple} when last expr is a tuple" do
    {problem, {p1, p2}} =
      ExPulp.model "tuple_return", :minimize do
        x = var(low: 0)
        y = var(low: 0)
        minimize x + y
        subject_to x + y >= 1
        {x, y}
      end

    assert %ExPulp.Problem{} = problem
    assert %ExPulp.Variable{name: "x"} = p1
    assert %ExPulp.Variable{name: "y"} = p2
  end

  @tag :solver
  test "returned vars can be used with Result.evaluate" do
    {problem, vars} =
      ExPulp.model "eval_vars", :minimize do
        x = var(low: 0, high: 10)
        y = var(low: 0, high: 10)
        minimize x + y
        subject_to x + y >= 5
        %{x: x, y: y}
      end

    {:ok, result} = ExPulp.solve(problem)
    assert ExPulp.Result.optimal?(result)

    x_val = ExPulp.Result.evaluate(result, vars.x)
    y_val = ExPulp.Result.evaluate(result, vars.y)
    assert is_float(x_val)
    assert is_float(y_val)
    assert_in_delta x_val + y_val, 5.0, 1.0e-6
  end

  @tag :solver
  test "returned indexed vars for result extraction" do
    items = [1, 2, 3]
    demands = %{1 => 5.0, 2 => 10.0, 3 => 15.0}

    {problem, vars} =
      ExPulp.model "indexed_return", :minimize do
        v = lp_vars("x", items, low: 0)

        minimize lp_sum(for i <- items, do: v[i])

        for i <- items do
          subject_to v[i] >= demands[i]
        end

        %{v: v}
      end

    {:ok, result} = ExPulp.solve(problem)

    for i <- items do
      val = ExPulp.Result.evaluate(result, vars.v[i])
      assert_in_delta val, demands[i], 1.0e-6
    end
  end

  @tag :solver
  test "returned multi-dim vars for EV charging pattern" do
    chargepoints = [:cp1, :cp2]
    slots = [1, 2]

    {problem, vars} =
      ExPulp.model "ev_return", :minimize do
        power = lp_vars("p", [chargepoints, slots], low: 0, high: 11)

        minimize lp_sum(for cp <- chargepoints, s <- slots, do: power[{cp, s}])

        for cp <- chargepoints do
          energy = lp_sum(for s <- slots, do: 0.25 * power[{cp, s}])
          subject_to energy >= 2.0
        end

        %{power: power}
      end

    {:ok, result} = ExPulp.solve(problem)
    assert ExPulp.Result.optimal?(result)

    # Extract values via the returned variable map
    for cp <- chargepoints do
      energy =
        Enum.sum(for s <- slots, do: 0.25 * ExPulp.Result.evaluate(result, vars.power[{cp, s}]))

      assert energy >= 2.0 - 1.0e-6
    end
  end
end
