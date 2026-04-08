defmodule Examples.QuickStart do
  @moduledoc """
  The Quick Start example from the README.

  A simple two-variable minimization problem:
  minimize `2x + 3y` subject to `x + y >= 5` with both variables bounded `[0, 10]`.

  **Known optimal: x=5, y=0, objective=10.**
  """

  require ExPulp

  def solve do
    problem = ExPulp.model "example", :minimize do
      x = var(low: 0, high: 10)
      y = var(low: 0, high: 10)

      minimize 2 * x + 3 * y
      subject_to "demand", x + y >= 5
    end

    ExPulp.solve(problem)
  end
end
