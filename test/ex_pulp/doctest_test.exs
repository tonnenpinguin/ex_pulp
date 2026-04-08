defmodule ExPulp.DoctestTest do
  use ExUnit.Case, async: true

  doctest ExPulp
  doctest ExPulp.Result
  doctest ExPulp.Problem
  doctest ExPulp.DSL.Helpers
  doctest ExPulp.Expression
end
