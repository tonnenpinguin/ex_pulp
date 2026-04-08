defmodule ExPulp.Solver.CBC do
  @moduledoc """
  CBC (COIN-OR Branch and Cut) solver integration.

  Writes the problem to a CPLEX LP file, invokes the `cbc` command-line binary,
  and parses the solution file. Supports LP and MIP (not QP).

  ## Prerequisites

  The `cbc` binary must be installed and available on your `PATH`:

      # macOS
      brew install cbc

      # Ubuntu/Debian
      apt-get install coinor-cbc

  ## Options

  The following options can be passed to `solve/2` or to `ExPulp.solve/2`:

    * `:path` - path to the `cbc` binary (default: `"cbc"`)
    * `:time_limit` - maximum solve time in seconds
    * `:keep_files` - if `true`, temporary LP and solution files are not deleted (default: `false`)

  ## Error handling

    * `{:error, {:solver_not_found, path}}` — `cbc` binary not found
    * `{:error, {:solver_error, exit_code, output}}` — `cbc` exited with non-zero code
    * `{:error, :no_solution_file}` — `cbc` did not produce a solution file
  """

  @behaviour ExPulp.Solver

  alias ExPulp.{Problem, Result, LpFormat}
  alias ExPulp.Solver.Util

  @default_path "cbc"

  @impl true
  def available? do
    System.find_executable(@default_path) != nil
  end

  @impl true
  def solve(%Problem{} = problem, opts \\ []) do
    path = Keyword.get(opts, :path, @default_path)
    time_limit = Keyword.get(opts, :time_limit)
    keep_files = Keyword.get(opts, :keep_files, false)

    cond do
      Problem.quadratic?(problem) ->
        {:error, :quadratic_not_supported}

      !System.find_executable(path) ->
        {:error, {:solver_not_found, path}}

      true ->
        do_solve(problem, path, time_limit, keep_files)
    end
  end

  defp do_solve(problem, path, time_limit, keep_files) do
    prefix = tmp_prefix()
    lp_file = prefix <> ".lp"
    sol_file = prefix <> ".sol"

    try do
      File.write!(lp_file, LpFormat.to_string(problem))

      args = build_args(lp_file, sol_file, problem, time_limit)
      {output, exit_code} = System.cmd(path, args, stderr_to_stdout: true)

      cond do
        exit_code != 0 ->
          {:error, {:solver_error, exit_code, output}}

        not File.exists?(sol_file) ->
          {:error, :no_solution_file}

        true ->
          result = parse_solution(sol_file, problem)
          {:ok, result}
      end
    after
      unless keep_files do
        File.rm(lp_file)
        File.rm(sol_file)
      end
    end
  end

  defp build_args(lp_file, sol_file, problem, time_limit) do
    args = [lp_file]

    args =
      if problem.sense == :maximize do
        args ++ ["-max"]
      else
        args
      end

    args =
      if time_limit do
        args ++ ["-sec", "#{time_limit}"]
      else
        args
      end

    args =
      if Problem.mip?(problem) do
        args ++ ["-branch"]
      else
        args ++ ["-initialSolve"]
      end

    args ++ ["-printingOptions", "all", "-solution", sol_file]
  end

  defp parse_solution(sol_file, problem) do
    content = File.read!(sol_file)
    lines = String.split(content, "\n")

    {status, status_line} =
      case lines do
        [first | _] -> {parse_status(first), first}
        _ -> {:not_solved, ""}
      end

    variable_names = Map.keys(problem.variables) |> MapSet.new()

    variables =
      lines
      |> tl()
      |> Enum.take_while(fn line -> String.length(line) > 2 end)
      |> Enum.map(&parse_sol_line/1)
      |> Enum.filter(fn {name, _val} -> MapSet.member?(variable_names, name) end)
      |> Map.new()

    variables = Util.round_integer_variables(variables, problem.variables)

    objective =
      if problem.objective && status in [:optimal, :feasible] do
        parse_objective_from_status(status_line)
      else
        nil
      end

    %Result{
      status: status,
      objective: objective,
      variables: if(status in [:optimal, :feasible], do: variables, else: %{})
    }
  end

  defp parse_status(line) do
    words = String.split(line)

    case List.first(words) do
      "Optimal" ->
        :optimal

      "Infeasible" ->
        :infeasible

      "Integer" ->
        if "infeasible" in words, do: :infeasible, else: :optimal

      "Unbounded" ->
        :unbounded

      "Stopped" ->
        if "objective" in words, do: :feasible, else: :not_solved

      _ ->
        :not_solved
    end
  end

  defp parse_objective_from_status(line) do
    case Regex.run(~r/objective value\s+(-?[\d.e+\-]+)/i, line) do
      [_, value_str] -> Util.parse_float(value_str)
      _ -> nil
    end
  end

  defp parse_sol_line(line) do
    parts = String.split(line)

    parts =
      case parts do
        ["**" | rest] -> rest
        other -> other
      end

    case parts do
      [_index, name, value | _rest] -> {name, Util.parse_float(value)}
      _ -> {"", 0.0}
    end
  end

  defp tmp_prefix, do: Util.tmp_prefix("cbc")
end
