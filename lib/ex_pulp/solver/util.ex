defmodule ExPulp.Solver.Util do
  @moduledoc false

  require Logger

  @doc """
  Parses a string as a float. Logs a warning and returns 0.0 on failure.
  """
  @spec parse_float(String.t()) :: float()
  def parse_float(str) do
    case Float.parse(str) do
      {val, _} ->
        val

      :error ->
        Logger.warning("ExPulp: failed to parse float from solver output: #{inspect(str)}")
        0.0
    end
  end

  @doc """
  Generates a unique temp file prefix.
  """
  @spec tmp_prefix(String.t()) :: String.t()
  def tmp_prefix(label) do
    random = :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
    Path.join(System.tmp_dir!(), "expulp_#{label}_#{random}")
  end

  @doc """
  Rounds integer variables to the nearest integer if within tolerance.
  """
  @spec round_integer_variables(%{String.t() => float()}, %{String.t() => ExPulp.Variable.t()}) ::
          %{String.t() => float()}
  def round_integer_variables(values, problem_variables) do
    Enum.reduce(problem_variables, values, fn {name, var}, acc ->
      if var.category == :integer do
        case Map.fetch(acc, name) do
          {:ok, val} ->
            rounded = round(val)

            if abs(val - rounded) < 1.0e-5 do
              Map.put(acc, name, rounded / 1)
            else
              acc
            end

          :error ->
            acc
        end
      else
        acc
      end
    end)
  end
end
