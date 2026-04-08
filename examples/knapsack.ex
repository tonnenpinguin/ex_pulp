defmodule Examples.Knapsack do
  @moduledoc """
  The 0-1 Knapsack Problem — a classic combinatorial optimization.

  A thief has a knapsack with a weight capacity of 15 kg. There are 5 items,
  each with a weight and a value. The thief must decide which items to take
  to maximize total value without exceeding the weight limit.

  | Item    | Weight | Value |
  |---------|--------|-------|
  | Gold    | 10     | 60    |
  | Silver  | 5      | 50    |
  | Bronze  | 4      | 40    |
  | Diamond | 1      | 30    |
  | Pearl   | 3      | 20    |

  **Known optimal value: 140** (take Silver + Bronze + Diamond + Pearl = weight 13, value 140).
  """

  require ExPulp

  def solve do
    items = [:gold, :silver, :bronze, :diamond, :pearl]
    weight = %{gold: 10, silver: 5, bronze: 4, diamond: 1, pearl: 3}
    value = %{gold: 60, silver: 50, bronze: 40, diamond: 30, pearl: 20}
    capacity = 15

    {problem, vars} = ExPulp.model "knapsack", :maximize do
      take = lp_binary_vars("take", items)

      maximize lp_weighted_sum(value, take)
      subject_to "capacity", lp_weighted_sum(weight, take) <= capacity

      %{take: take}
    end

    case ExPulp.solve(problem) do
      {:ok, result} ->
        selected =
          for i <- items,
              ExPulp.Result.evaluate(result, vars.take[i]) > 0.5,
              do: i

        {:ok, %{value: result.objective, selected: selected, status: result.status}}

      error ->
        error
    end
  end
end
