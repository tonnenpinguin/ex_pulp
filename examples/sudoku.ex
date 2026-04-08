defmodule Examples.Sudoku do
  @moduledoc """
  Sudoku as an Integer Program.

  Models the classic 9x9 Sudoku puzzle as a binary IP. For each cell (r, c)
  and each digit d in 1..9, a binary variable `x[{r, c, d}]` indicates
  whether digit d is placed in cell (r, c).

  Constraints:
  - Each cell has exactly one digit
  - Each row has each digit exactly once
  - Each column has each digit exactly once
  - Each 3x3 box has each digit exactly once
  - Pre-filled cells are fixed

  The puzzle used is a standard easy Sudoku:

  ```
  5 3 _  _ 7 _  _ _ _
  6 _ _  1 9 5  _ _ _
  _ 9 8  _ _ _  _ 6 _

  8 _ _  _ 6 _  _ _ 3
  4 _ _  8 _ 3  _ _ 1
  7 _ _  _ 2 _  _ _ 6

  _ 6 _  _ _ _  2 8 _
  _ _ _  4 1 9  _ _ 5
  _ _ _  _ 8 _  _ 7 9
  ```
  """

  require ExPulp

  @givens [
    {1, 1, 5}, {1, 2, 3}, {1, 5, 7},
    {2, 1, 6}, {2, 4, 1}, {2, 5, 9}, {2, 6, 5},
    {3, 2, 9}, {3, 3, 8}, {3, 8, 6},
    {4, 1, 8}, {4, 5, 6}, {4, 9, 3},
    {5, 1, 4}, {5, 4, 8}, {5, 6, 3}, {5, 9, 1},
    {6, 1, 7}, {6, 5, 2}, {6, 9, 6},
    {7, 2, 6}, {7, 7, 2}, {7, 8, 8},
    {8, 4, 4}, {8, 5, 1}, {8, 6, 9}, {8, 9, 5},
    {9, 5, 8}, {9, 8, 7}, {9, 9, 9}
  ]

  def solve do
    rows = 1..9
    cols = 1..9
    digits = 1..9

    {problem, vars} = ExPulp.model "sudoku", :minimize do
      # Binary variable: x[{r, c, d}] = 1 if digit d is in cell (r, c)
      x = lp_vars("x", [rows, cols, digits], category: :binary)

      # Dummy objective (feasibility problem)
      minimize 0

      # Each cell has exactly one digit
      for r <- rows, c <- cols do
        subject_to lp_sum(for d <- digits, do: x[{r, c, d}]) == 1
      end

      # Each row has each digit exactly once
      for r <- rows, d <- digits do
        subject_to lp_sum(for c <- cols, do: x[{r, c, d}]) == 1
      end

      # Each column has each digit exactly once
      for c <- cols, d <- digits do
        subject_to lp_sum(for r <- rows, do: x[{r, c, d}]) == 1
      end

      # Each 3x3 box has each digit exactly once
      for br <- [0, 3, 6], bc <- [0, 3, 6], d <- digits do
        subject_to lp_sum(
          for r <- (br + 1)..(br + 3), c <- (bc + 1)..(bc + 3), do: x[{r, c, d}]
        ) == 1
      end

      # Fix given digits
      for {r, c, d} <- @givens do
        subject_to x[{r, c, d}] == 1
      end

      %{x: x}
    end

    case ExPulp.solve(problem) do
      {:ok, result} ->
        grid =
          for r <- rows do
            for c <- cols do
              Enum.find(digits, fn d ->
                ExPulp.Result.evaluate(result, vars.x[{r, c, d}]) > 0.5
              end)
            end
          end

        {:ok, %{grid: grid, status: result.status}}

      error ->
        error
    end
  end

  @doc "Prints the solved grid to stdout."
  def print_grid(grid) do
    for {row, r} <- Enum.with_index(grid, 1) do
      line =
        row
        |> Enum.with_index(1)
        |> Enum.map(fn {d, c} ->
          sep = if rem(c, 3) == 0 and c < 9, do: " |", else: ""
          " #{d}#{sep}"
        end)
        |> Enum.join()

      IO.puts(line)
      if rem(r, 3) == 0 and r < 9, do: IO.puts(" ------+-------+------")
    end
  end
end
