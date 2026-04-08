defmodule ExPulp.Solver.HiGHS do
  @moduledoc """
  HiGHS solver integration.

  [HiGHS](https://highs.dev) is a high-performance open-source solver for linear
  programming (LP), mixed-integer programming (MIP), and quadratic programming (QP).
  It is often significantly faster than CBC, particularly on larger MIP problems.

  ## Prerequisites

  The `highs` binary must be installed and available on your `PATH`:

      # macOS
      brew install highs

      # Ubuntu/Debian
      apt-get install highs

  ## Usage

      {:ok, result} = ExPulp.solve(problem, solver: ExPulp.Solver.HiGHS)

  ## Options

  The following options can be passed to `solve/2`:

    * `:path` - path to the `highs` binary (default: `"highs"`)
    * `:time_limit` - maximum solve time in seconds
    * `:threads` - number of threads for parallel solving
    * `:gap_rel` - relative MIP gap tolerance (e.g. `0.01` for 1%)
    * `:gap_abs` - absolute MIP gap tolerance
    * `:keep_files` - if `true`, temporary files are not deleted (default: `false`)
    * `:log` - if `false`, suppresses solver output (default: `false`)
  """

  @behaviour ExPulp.Solver

  alias ExPulp.{Problem, Result, LpFormat}
  alias ExPulp.Solver.Util

  @default_path "highs"

  @impl true
  def available? do
    System.find_executable(@default_path) != nil
  end

  @impl true
  def solve(%Problem{} = problem, opts \\ []) do
    path = Keyword.get(opts, :path, @default_path)

    unless System.find_executable(path) do
      {:error, {:solver_not_found, path}}
    else
      do_solve(problem, path, opts)
    end
  end

  defp do_solve(problem, path, opts) do
    prefix = tmp_prefix()
    lp_file = prefix <> ".lp"
    sol_file = prefix <> ".sol"
    opts_file = prefix <> ".opts"
    log_file = prefix <> ".log"
    keep_files = Keyword.get(opts, :keep_files, false)

    try do
      File.write!(lp_file, LpFormat.to_string(problem))
      File.write!(opts_file, build_options_file(sol_file, log_file, opts))

      args = build_args(lp_file, opts_file, opts)
      {output, exit_code} = System.cmd(path, args, stderr_to_stdout: true)

      cond do
        exit_code not in [0, 1] ->
          {:error, {:solver_error, exit_code, output}}

        not File.exists?(sol_file) or File.stat!(sol_file).size == 0 ->
          {:error, :no_solution_file}

        true ->
          {status, sol_status} = parse_log_status(log_file)
          result = parse_solution(sol_file, problem, status, sol_status)
          {:ok, result}
      end
    after
      unless keep_files do
        for f <- [lp_file, sol_file, opts_file, log_file], do: File.rm(f)
      end
    end
  end

  defp build_options_file(sol_file, log_file, opts) do
    lines = [
      "solution_file = #{sol_file}",
      "write_solution_to_file = true",
      "write_solution_style = 0",
      "log_file = #{log_file}"
    ]

    lines =
      if Keyword.get(opts, :log, false),
        do: lines,
        else: lines ++ ["log_to_console = false"]

    lines =
      case Keyword.get(opts, :threads) do
        nil -> lines
        n -> lines ++ ["threads = #{n}"]
      end

    lines =
      case Keyword.get(opts, :gap_rel) do
        nil -> lines
        g -> lines ++ ["mip_rel_gap = #{g}"]
      end

    lines =
      case Keyword.get(opts, :gap_abs) do
        nil -> lines
        g -> lines ++ ["mip_abs_gap = #{g}"]
      end

    Enum.join(lines, "\n")
  end

  defp build_args(lp_file, opts_file, opts) do
    args = [lp_file, "--options_file", opts_file]

    case Keyword.get(opts, :time_limit) do
      nil -> args
      t -> args ++ ["--time_limit", "#{t}"]
    end
  end

  defp parse_log_status(log_file) do
    lines =
      case File.read(log_file) do
        {:ok, content} -> content |> String.split("\n") |> Enum.map(&String.split/1)
        _ -> []
      end

    model_line =
      Enum.find(lines, fn
        ["Model", "status" | _] -> true
        _ -> false
      end)

    model_status =
      case model_line do
        ["Model", "status" | rest] -> rest |> Enum.join(" ") |> String.trim()
        _ -> nil
      end

    sol_line =
      Enum.find(lines, fn
        ["Solution", "status" | _] -> true
        _ -> false
      end)

    sol_status =
      case sol_line do
        ["Solution", "status" | rest] -> rest |> Enum.join(" ") |> String.trim()
        _ -> nil
      end

    # Also check for MIP status lines like "Status            Optimal"
    status_line =
      Enum.find(lines, fn
        ["Status" | _rest] -> true
        _ -> false
      end)

    mip_status =
      case status_line do
        ["Status" | rest] -> rest |> Enum.join(" ") |> String.trim()
        _ -> nil
      end

    effective_model_status = model_status || mip_status

    categorize_status(effective_model_status, sol_status)
  end

  defp categorize_status(model_status, sol_status) do
    model_lower = if model_status, do: String.downcase(model_status), else: ""
    sol_lower = if sol_status, do: String.downcase(sol_status), else: ""

    cond do
      model_lower == "optimal" -> {:optimal, :optimal}
      sol_lower == "feasible" -> {:optimal, :feasible}
      model_lower == "infeasible" -> {:infeasible, :infeasible}
      model_lower == "unbounded" -> {:unbounded, :unbounded}
      true -> {:not_solved, :not_solved}
    end
  end

  defp parse_solution(sol_file, problem, status, _sol_status) do
    content = File.read!(sol_file)
    lines = String.split(content, "\n")

    # Parse model status from solution file
    file_status = parse_solution_model_status(lines, status)

    variables =
      if file_status in [:optimal] do
        parse_column_values(lines, problem)
      else
        %{}
      end

    objective = parse_objective(lines)

    %Result{
      status: file_status,
      objective: if(file_status == :optimal, do: objective, else: nil),
      variables: variables
    }
  end

  defp parse_solution_model_status(lines, fallback) do
    # Line 2 of solution file is the model status
    case Enum.at(lines, 1) do
      "Optimal" -> :optimal
      "Infeasible" -> :infeasible
      "Unbounded" -> :unbounded
      _ -> fallback
    end
  end

  defp parse_objective(lines) do
    # Find "Objective <value>" line
    Enum.find_value(lines, nil, fn line ->
      case String.split(line) do
        ["Objective", val] -> Util.parse_float(val)
        _ -> nil
      end
    end)
  end

  defp parse_column_values(lines, problem) do
    variable_names = Map.keys(problem.variables) |> MapSet.new()

    # Find the "# Columns N" line, read N lines after it
    {_state, values} =
      Enum.reduce(lines, {:scanning, %{}}, fn line, {state, acc} ->
        case state do
          :scanning ->
            if String.starts_with?(line, "# Columns") do
              {:reading_columns, acc}
            else
              {:scanning, acc}
            end

          :reading_columns ->
            cond do
              String.starts_with?(line, "#") or line == "" ->
                {:done, acc}

              true ->
                case String.split(line) do
                  [name, val] when is_binary(name) ->
                    if MapSet.member?(variable_names, name) do
                      {:reading_columns, Map.put(acc, name, Util.parse_float(val))}
                    else
                      {:reading_columns, acc}
                    end

                  _ ->
                    {:reading_columns, acc}
                end
            end

          :done ->
            {:done, acc}
        end
      end)

    Util.round_integer_variables(values, problem.variables)
  end

  defp tmp_prefix, do: Util.tmp_prefix("highs")
end
