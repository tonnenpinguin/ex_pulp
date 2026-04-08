defmodule ExamplesTest do
  use ExUnit.Case

  @moduletag :solver

  describe "Quick Start (README example)" do
    test "finds optimal x=5, y=0, objective=10" do
      {:ok, result} = Examples.QuickStart.solve()
      assert result.status == :optimal
      assert_in_delta result.objective, 10.0, 1.0e-6
      assert_in_delta result.variables["x"], 5.0, 1.0e-6
      assert_in_delta result.variables["y"], 0.0, 1.0e-6
    end
  end

  describe "Whiskas diet problem" do
    test "finds optimal blend at ~$0.52" do
      {:ok, result} = Examples.Whiskas.solve()
      assert result.status == :optimal
      assert_in_delta result.cost, 0.52, 0.01

      # Blend sums to 100g
      total = result.blend |> Map.values() |> Enum.sum()
      assert_in_delta total, 100.0, 1.0e-6
    end
  end

  describe "Transportation problem" do
    test "finds optimal cost of $80" do
      {:ok, result} = Examples.Transportation.solve()
      assert result.status == :optimal
      assert_in_delta result.cost, 80.0, 1.0e-6

      # Factory A -> Warehouse 1: 20 units
      assert_in_delta result.shipments[{:factory_a, :warehouse_1}], 20.0, 1.0e-6
      # Factory B -> Warehouse 2: 40 units
      assert_in_delta result.shipments[{:factory_b, :warehouse_2}], 40.0, 1.0e-6
    end
  end

  describe "Knapsack problem" do
    test "finds optimal value of 140" do
      {:ok, result} = Examples.Knapsack.solve()
      assert result.status == :optimal
      assert_in_delta result.value, 140.0, 1.0e-6

      # Optimal selection: silver (50) + bronze (40) + diamond (30) + pearl (20)
      # weight: 5 + 4 + 1 + 3 = 13 <= 15
      assert :silver in result.selected
      assert :bronze in result.selected
      assert :diamond in result.selected
      assert :pearl in result.selected
      refute :gold in result.selected
    end
  end

  describe "Sudoku solver" do
    test "produces valid complete grid" do
      {:ok, result} = Examples.Sudoku.solve()
      assert result.status == :optimal

      grid = result.grid

      # 9 rows, 9 columns
      assert length(grid) == 9
      assert Enum.all?(grid, &(length(&1) == 9))

      # Every cell has a digit 1-9
      assert Enum.all?(List.flatten(grid), &(&1 in 1..9))

      # Each row has all digits 1-9
      for row <- grid do
        assert Enum.sort(row) == Enum.to_list(1..9)
      end

      # Each column has all digits 1-9
      for c <- 0..8 do
        col = Enum.map(grid, &Enum.at(&1, c))
        assert Enum.sort(col) == Enum.to_list(1..9)
      end

      # Each 3x3 box has all digits 1-9
      for br <- [0, 3, 6], bc <- [0, 3, 6] do
        box =
          for r <- br..(br + 2), c <- bc..(bc + 2) do
            grid |> Enum.at(r) |> Enum.at(c)
          end

        assert Enum.sort(box) == Enum.to_list(1..9)
      end

      # Check some givens
      assert grid |> Enum.at(0) |> Enum.at(0) == 5
      assert grid |> Enum.at(0) |> Enum.at(1) == 3
      assert grid |> Enum.at(0) |> Enum.at(4) == 7
    end
  end
end
