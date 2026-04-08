defmodule ExPulp.DoctestTest do
  @moduledoc """
  Centralized doctests for modules that don't have their own test file
  running doctests. Modules with dedicated test files (Expression, Constraint,
  Variable) run their own doctests there.
  """
  use ExUnit.Case, async: true

  doctest ExPulp
  doctest ExPulp.Result
  doctest ExPulp.Problem
  doctest ExPulp.DSL.Helpers
end
