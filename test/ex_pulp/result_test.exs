defmodule ExPulp.ResultTest do
  use ExUnit.Case, async: true

  alias ExPulp.{Variable, Result}

  test "optimal?/1" do
    assert Result.optimal?(%Result{status: :optimal})
    refute Result.optimal?(%Result{status: :infeasible})
    refute Result.optimal?(%Result{status: :unbounded})
    refute Result.optimal?(%Result{status: :not_solved})
  end

  test "feasible?/1" do
    assert Result.feasible?(%Result{status: :optimal})
    refute Result.feasible?(%Result{status: :infeasible})
    refute Result.feasible?(%Result{status: :not_solved})
  end

  test "infeasible?/1" do
    assert Result.infeasible?(%Result{status: :infeasible})
    refute Result.infeasible?(%Result{status: :optimal})
  end

  test "unbounded?/1" do
    assert Result.unbounded?(%Result{status: :unbounded})
    refute Result.unbounded?(%Result{status: :optimal})
  end

  test "get_variable/2 with string" do
    result = %Result{status: :optimal, variables: %{"x" => 5.0, "y" => 3.0}}
    assert Result.get_variable(result, "x") == 5.0
    assert Result.get_variable(result, "z") == nil
  end

  test "get_variable/2 with Variable struct" do
    x = Variable.new("x")
    result = %Result{status: :optimal, variables: %{"x" => 5.0}}
    assert Result.get_variable(result, x) == 5.0
  end

  test "num_variables/1" do
    result = %Result{variables: %{"x" => 1.0, "y" => 2.0}}
    assert Result.num_variables(result) == 2
  end
end
