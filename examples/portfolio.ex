defmodule Examples.Portfolio do
  @moduledoc """
  Markowitz Mean-Variance Portfolio Optimization (Quadratic Programming).

  Given 3 assets with expected returns and a covariance matrix, find the
  portfolio weights that minimize variance (risk) while achieving at least
  a target return of 10%.

  | Asset | Expected Return | Std Dev |
  |-------|----------------|---------|
  | A     | 12%            | 10%     |
  | B     | 10%            | 8%      |
  | C     | 7%             | 5%      |

  Covariance matrix:
  ```
       A       B       C
  A  0.0100  0.0018  0.0011
  B  0.0018  0.0064  0.0026
  C  0.0011  0.0026  0.0025
  ```

  Constraints:
  - Weights sum to 1 (fully invested)
  - Minimum expected return of 10%
  - No short selling (weights >= 0)

  Requires HiGHS solver (CBC does not support quadratic objectives).
  """

  require ExPulp

  def solve do
    assets = [:a, :b, :c]
    returns = %{a: 0.12, b: 0.10, c: 0.07}

    # Covariance matrix (symmetric)
    cov = %{
      {:a, :a} => 0.0100, {:a, :b} => 0.0018, {:a, :c} => 0.0011,
      {:b, :a} => 0.0018, {:b, :b} => 0.0064, {:b, :c} => 0.0026,
      {:c, :a} => 0.0011, {:c, :b} => 0.0026, {:c, :c} => 0.0025
    }

    target_return = 0.10

    {problem, vars} = ExPulp.model "portfolio", :minimize do
      w = lp_vars("w", assets, low: 0, high: 1)

      # Minimize portfolio variance: w' * Cov * w
      # = sum over all (i,j) pairs of cov[i,j] * w[i] * w[j]
      variance =
        lp_sum(
          for i <- assets, j <- assets do
            cov[{i, j}] * w[i] * w[j]
          end
        )

      minimize variance

      # Weights sum to 1
      subject_to "fully_invested", lp_sum(for i <- assets, do: w[i]) == 1

      # Minimum return
      subject_to "min_return", lp_weighted_sum(returns, w) >= target_return

      %{w: w}
    end

    case ExPulp.solve(problem) do
      {:ok, result} ->
        weights =
          for i <- assets, into: %{} do
            {i, ExPulp.Result.evaluate(result, vars.w[i])}
          end

        portfolio_return =
          Enum.sum(for i <- assets, do: returns[i] * weights[i])

        {:ok,
         %{
           variance: result.objective,
           weights: weights,
           return: portfolio_return,
           status: result.status
         }}

      error ->
        error
    end
  end
end
