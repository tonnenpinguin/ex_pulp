defmodule ExPulp.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/tonnenpinguin/ex_pulp"

  def project do
    [
      app: :ex_pulp,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      name: "ExPulp",
      description: "A linear and mixed-integer programming modeler for Elixir with a natural DSL",
      source_url: @source_url,
      docs: docs(),
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto]
    ]
  end

  defp elixirc_paths(:prod), do: ["lib"]
  defp elixirc_paths(_), do: ["lib", "examples"]

  defp deps do
    [
      {:ex_doc, "~> 0.35", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "ExPulp",
      extras: ["README.md"],
      groups_for_modules: [
        "Core Types": [
          ExPulp.Variable,
          ExPulp.Expression,
          ExPulp.Constraint,
          ExPulp.Problem,
          ExPulp.Result
        ],
        DSL: [
          ExPulp.DSL,
          ExPulp.DSL.Operators,
          ExPulp.DSL.Helpers,
          ExPulp.DSL.Builder
        ],
        Solvers: [
          ExPulp.Solver,
          ExPulp.Solver.CBC,
          ExPulp.Solver.HiGHS
        ],
        Serialization: [
          ExPulp.LpFormat
        ],
        Examples: [
          Examples.QuickStart,
          Examples.Whiskas,
          Examples.Knapsack,
          Examples.Transportation,
          Examples.Sudoku
        ]
      ]
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end
end
