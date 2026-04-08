defmodule Examples.Whiskas do
  @moduledoc """
  The Whiskas Cat Food Problem — a classic diet optimization.

  A pet food company wants to produce cans of cat food as cheaply as possible
  while meeting nutritional requirements. Each can must contain 100g made from
  a blend of ingredients, each with different costs and nutritional profiles.

  This is the canonical PuLP example from the
  [PuLP documentation](https://coin-or.github.io/pulp/CaseStudies/a_blending_problem.html).

  **Known optimal cost: ~$0.52 per can.**
  """

  require ExPulp

  def solve do
    ingredients = ~w(chicken beef mutton rice wheat gel)

    costs = %{
      "chicken" => 0.013,
      "beef" => 0.008,
      "mutton" => 0.010,
      "rice" => 0.002,
      "wheat" => 0.005,
      "gel" => 0.001
    }

    protein = %{
      "chicken" => 0.100,
      "beef" => 0.200,
      "mutton" => 0.150,
      "rice" => 0.000,
      "wheat" => 0.040,
      "gel" => 0.000
    }

    fat = %{
      "chicken" => 0.080,
      "beef" => 0.100,
      "mutton" => 0.110,
      "rice" => 0.010,
      "wheat" => 0.010,
      "gel" => 0.000
    }

    fibre = %{
      "chicken" => 0.001,
      "beef" => 0.005,
      "mutton" => 0.003,
      "rice" => 0.100,
      "wheat" => 0.150,
      "gel" => 0.000
    }

    salt = %{
      "chicken" => 0.002,
      "beef" => 0.005,
      "mutton" => 0.007,
      "rice" => 0.002,
      "wheat" => 0.008,
      "gel" => 0.000
    }

    {problem, vars} = ExPulp.model "whiskas", :minimize do
      vars = lp_vars("ingr", ingredients, low: 0)

      minimize lp_weighted_sum(costs, vars)

      subject_to "total_weight", lp_sum(for i <- ingredients, do: vars[i]) == 100
      subject_to "protein", lp_weighted_sum(protein, vars) >= 8.0
      subject_to "fat",     lp_weighted_sum(fat, vars) >= 6.0
      subject_to "fibre",   lp_weighted_sum(fibre, vars) <= 2.0
      subject_to "salt",    lp_weighted_sum(salt, vars) <= 0.4

      %{vars: vars}
    end

    case ExPulp.solve(problem) do
      {:ok, result} ->
        blend =
          for i <- ingredients, into: %{} do
            {i, ExPulp.Result.evaluate(result, vars.vars[i])}
          end

        {:ok, %{cost: result.objective, blend: blend, status: result.status}}

      error ->
        error
    end
  end
end
