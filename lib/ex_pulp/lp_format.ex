defmodule ExPulp.LpFormat do
  @moduledoc """
  Serializes a `Problem` to CPLEX LP file format.

  The LP format is a human-readable format supported by most LP solvers including
  CBC, GLPK, CPLEX, and Gurobi. It consists of sections for the objective,
  constraints, bounds, integer variables, and binary variables.

  ## Example output

      \\* my_problem *\\
      Minimize
      OBJ: 2 x + 3 y
      Subject To
      demand: x + y >= 5
      Bounds
      0 <= x <= 10
      0 <= y <= 10
      End

  This module is used internally by `ExPulp.Solver.CBC` and is not typically
  called directly. Use `ExPulp.LpFormat.to_string/1` to inspect the generated LP.
  """

  alias ExPulp.{Problem, Expression, Constraint, Variable}

  @doc """
  Converts a problem to LP format string.
  """
  @spec to_string(Problem.t()) :: String.t()
  def to_string(%Problem{} = problem) do
    vars = Problem.variables_sorted(problem)

    [
      write_header(problem),
      write_sense(problem),
      write_objective(problem),
      write_constraints(problem),
      write_bounds(vars),
      write_generals(vars),
      write_binaries(vars),
      "End\n"
    ]
    |> Enum.reject(&is_nil/1)
    |> IO.iodata_to_binary()
  end

  defp write_header(%Problem{name: name}), do: "\\* #{name} *\\\n"

  defp write_sense(%Problem{sense: :minimize}), do: "Minimize\n"
  defp write_sense(%Problem{sense: :maximize}), do: "Maximize\n"

  defp write_objective(%Problem{objective: nil}), do: "OBJ: 0\n"

  defp write_objective(%Problem{objective: expr}) do
    "#{format_expression(expr, "OBJ")}\n"
  end

  defp write_constraints(%Problem{constraints: []}), do: nil

  defp write_constraints(%Problem{constraints: constraints}) do
    lines =
      Enum.map(constraints, fn {name, constraint} ->
        format_constraint(name, constraint)
      end)

    "Subject To\n#{Enum.join(lines)}"
  end

  defp write_bounds(vars) do
    bound_vars =
      Enum.reject(vars, fn v ->
        Variable.default_positive?(v) or Variable.binary?(v)
      end)

    case bound_vars do
      [] -> nil
      vars -> "Bounds\n#{Enum.map_join(vars, &format_bound/1)}"
    end
  end

  defp write_generals(vars) do
    generals =
      Enum.filter(vars, fn v -> v.category == :integer and not Variable.binary?(v) end)

    case generals do
      [] -> nil
      vars -> "Generals\n#{Enum.map_join(vars, fn v -> " #{v.name}\n" end)}"
    end
  end

  defp write_binaries(vars) do
    binaries = Enum.filter(vars, &Variable.binary?/1)

    case binaries do
      [] -> nil
      vars -> "Binaries\n#{Enum.map_join(vars, fn v -> " #{v.name}\n" end)}"
    end
  end

  defp format_expression(%Expression{} = expr, label) do
    sorted_vars = Expression.sorted_variables(expr)

    terms =
      sorted_vars
      |> Enum.with_index()
      |> Enum.map(fn {var, idx} ->
        coeff = Map.fetch!(expr.terms, var)
        format_term(coeff, var.name, idx == 0)
      end)
      |> Enum.join("")

    terms = if terms == "", do: " 0", else: terms

    "#{label}:#{terms}"
  end

  defp format_constraint(name, %Constraint{} = c) do
    sorted_vars = Expression.sorted_variables(c.expression)

    terms =
      sorted_vars
      |> Enum.with_index()
      |> Enum.map(fn {var, idx} ->
        coeff = Map.fetch!(c.expression.terms, var)
        format_term(coeff, var.name, idx == 0)
      end)
      |> Enum.join("")

    terms = if terms == "", do: " 0", else: terms
    rhs = Constraint.effective_rhs(c)
    rhs_str = format_number(rhs)

    "#{name}:#{terms} #{Constraint.sense_string(c.sense)} #{rhs_str}\n"
  end

  defp format_term(coeff, var_name, first?) do
    cond do
      coeff == 1 && first? -> " #{var_name}"
      coeff == 1 -> " + #{var_name}"
      coeff == -1 && first? -> " - #{var_name}"
      coeff == -1 -> " - #{var_name}"
      coeff > 0 && first? -> " #{format_number(coeff)} #{var_name}"
      coeff > 0 -> " + #{format_number(coeff)} #{var_name}"
      coeff < 0 && first? -> " - #{format_number(abs(coeff))} #{var_name}"
      coeff < 0 -> " - #{format_number(abs(coeff))} #{var_name}"
      true -> ""
    end
  end

  defp format_bound(%Variable{} = v) do
    cond do
      v.low != nil && v.low == v.high ->
        " #{v.name} = #{format_number(v.low)}\n"

      v.low == nil && v.high == nil ->
        " #{v.name} free\n"

      v.low == nil ->
        " -inf <= #{v.name} <= #{format_number(v.high)}\n"

      v.high == nil ->
        " #{format_number(v.low)} <= #{v.name}\n"

      true ->
        " #{format_number(v.low)} <= #{v.name} <= #{format_number(v.high)}\n"
    end
  end

  defp format_number(n) when is_integer(n), do: Integer.to_string(n)

  defp format_number(n) when is_float(n) do
    :erlang.float_to_binary(n, [:compact, decimals: 12])
  end
end
