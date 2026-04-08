defmodule Examples.Transportation do
  @moduledoc """
  The Transportation Problem — a classic network optimization.

  Two factories supply two warehouses. Each factory has a limited supply,
  each warehouse has a required demand, and shipping from each factory to
  each warehouse has a different cost per unit. Find the cheapest shipping plan.

  ```
            Warehouse 1   Warehouse 2   Supply
  Factory A     $2            $4          30
  Factory B     $5            $1          50
  Demand        20            40
  ```

  **Known optimal cost: $80** (Factory A ships 20 to W1, Factory B ships 40 to W2).
  """

  require ExPulp

  def solve do
    sources = [:factory_a, :factory_b]
    destinations = [:warehouse_1, :warehouse_2]

    supply = %{factory_a: 30, factory_b: 50}
    demand = %{warehouse_1: 20, warehouse_2: 40}

    cost = %{
      {:factory_a, :warehouse_1} => 2,
      {:factory_a, :warehouse_2} => 4,
      {:factory_b, :warehouse_1} => 5,
      {:factory_b, :warehouse_2} => 1
    }

    {problem, vars} = ExPulp.model "transportation", :minimize do
      flow = lp_vars("flow", [sources, destinations], low: 0)

      minimize lp_sum(
        for s <- sources, d <- destinations, do: cost[{s, d}] * flow[{s, d}]
      )

      for s <- sources do
        subject_to "supply_#{s}",
          lp_sum(for d <- destinations, do: flow[{s, d}]) <= supply[s]
      end

      for d <- destinations do
        subject_to "demand_#{d}",
          lp_sum(for s <- sources, do: flow[{s, d}]) >= demand[d]
      end

      %{flow: flow}
    end

    case ExPulp.solve(problem) do
      {:ok, result} ->
        shipments =
          for s <- sources, d <- destinations, into: %{} do
            {{s, d}, ExPulp.Result.evaluate(result, vars.flow[{s, d}])}
          end

        {:ok, %{cost: result.objective, shipments: shipments, status: result.status}}

      error ->
        error
    end
  end
end
