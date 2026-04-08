defmodule ExPulp.Solver do
  @moduledoc """
  Behaviour for LP/MIP solvers.

  Implement this behaviour to add support for a new solver backend.
  The default solver is `ExPulp.Solver.CBC`.

  ## Implementing a solver

      defmodule MyApp.Solver.GLPK do
        @behaviour ExPulp.Solver

        @impl true
        def available?, do: System.find_executable("glpsol") != nil

        @impl true
        def solve(problem, opts) do
          # Write problem, invoke solver, parse results
          # Return {:ok, %ExPulp.Result{}} or {:error, reason}
        end
      end
  """

  alias ExPulp.{Problem, Result}

  @callback solve(Problem.t(), keyword()) :: {:ok, Result.t()} | {:error, term()}
  @callback available?() :: boolean()
end
