defmodule ExPulp.QuadraticTest do
  use ExUnit.Case, async: true

  alias ExPulp.{Variable, Expression}

  setup do
    x = Variable.new("x")
    y = Variable.new("y")
    z = Variable.new("z")
    %{x: x, y: y, z: z}
  end

  describe "quadratic term creation" do
    test "var * var produces quadratic", %{x: x} do
      expr = Expression.multiply(x, x)
      assert Expression.quadratic?(expr)
      assert Expression.to_string(expr) == "x^2"
    end

    test "var * different var produces cross term", %{x: x, y: y} do
      expr = Expression.multiply(x, y)
      assert Expression.to_string(expr) == "x*y"
    end

    test "y * x produces same canonical order as x * y", %{x: x, y: y} do
      expr1 = Expression.multiply(x, y)
      expr2 = Expression.multiply(y, x)
      assert Expression.to_string(expr1) == Expression.to_string(expr2)
    end

    test "scalar * var * var", %{x: x, y: y} do
      # 2 * x * y  =>  first 2*x gives expression, then expr * y gives quad
      expr = Expression.multiply(Expression.multiply(2, x), y)
      assert Expression.to_string(expr) == "2*x*y"
    end

    test "expression * expression distributes", %{x: x, y: y} do
      # (x + y) * (x + y) = x^2 + 2*x*y + y^2
      sum = Expression.add(x, y)
      result = Expression.multiply(sum, sum)
      assert Expression.to_string(result) == "x^2 + y^2 + 2*x*y"
    end

    test "(2*x + 3) * (y + 1) distributes fully", %{x: x, y: y} do
      a = Expression.add(Expression.multiply(2, x), 3)
      b = Expression.add(Expression.from_variable(y), 1)
      result = Expression.multiply(a, b)
      # 2*x*y + 2*x + 3*y + 3
      assert Expression.quadratic?(result)
      assert result.constant == 3.0
    end
  end

  describe "quadratic arithmetic" do
    test "adding two quadratic expressions merges quad_terms", %{x: x, y: y} do
      a = Expression.multiply(x, x)
      b = Expression.multiply(y, y)
      result = Expression.add(a, b)
      assert Expression.to_string(result) == "x^2 + y^2"
    end

    test "adding same quad term sums coefficients", %{x: x} do
      a = Expression.multiply(x, x)
      result = Expression.add(a, a)
      assert Expression.to_string(result) == "2*x^2"
    end

    test "scaling quadratic expression", %{x: x, y: y} do
      expr = Expression.multiply(x, y)
      result = Expression.scale(expr, 3)
      assert Expression.to_string(result) == "3*x*y"
    end

    test "negating quadratic expression", %{x: x} do
      expr = Expression.multiply(x, x)
      result = Expression.negate(expr)
      assert Expression.to_string(result) == "-x^2"
    end

    test "adding quadratic and linear", %{x: x, y: y} do
      quad = Expression.multiply(x, x)
      linear = Expression.from_variable(y, 3)
      result = Expression.add(quad, linear)
      assert Expression.to_string(result) == "x^2 + 3*y"
    end

    test "subtracting quadratic terms", %{x: x} do
      a = Expression.scale(Expression.multiply(x, x), 3)
      b = Expression.multiply(x, x)
      result = Expression.subtract(a, b)
      assert Expression.to_string(result) == "2*x^2"
    end
  end

  describe "quadratic?/1" do
    test "linear expression is not quadratic", %{x: x} do
      refute Expression.quadratic?(Expression.from_variable(x))
    end

    test "empty expression is not quadratic" do
      refute Expression.quadratic?(Expression.new())
    end

    test "quad expression is quadratic", %{x: x} do
      assert Expression.quadratic?(Expression.multiply(x, x))
    end
  end

  describe "evaluate with quadratic" do
    test "evaluates x^2", %{x: x} do
      expr = Expression.multiply(x, x)
      assert Expression.evaluate(expr, %{"x" => 3.0}) == 9.0
    end

    test "evaluates x*y", %{x: x, y: y} do
      expr = Expression.multiply(x, y)
      assert Expression.evaluate(expr, %{"x" => 3.0, "y" => 4.0}) == 12.0
    end

    test "evaluates full quadratic: x^2 + 2*x*y + y^2 + x + 1", %{x: x, y: y} do
      quad = Expression.multiply(Expression.add(x, y), Expression.add(x, y))
      full = Expression.add(Expression.add(quad, Expression.from_variable(x)), 1)
      # (x+y)^2 + x + 1 = x^2 + 2xy + y^2 + x + 1
      # at x=2, y=3: 4 + 12 + 9 + 2 + 1 = 28
      assert Expression.evaluate(full, %{"x" => 2.0, "y" => 3.0}) == 28.0
    end

    test "returns nil for missing variable in quad term", %{x: x, y: y} do
      expr = Expression.multiply(x, y)
      assert Expression.evaluate(expr, %{"x" => 1.0}) == nil
    end
  end

  describe "sorted_variables with quadratic" do
    test "includes variables from quad terms only", %{x: x, y: y} do
      expr = Expression.multiply(x, y)
      names = Expression.sorted_variables(expr) |> Enum.map(& &1.name)
      assert names == ["x", "y"]
    end

    test "deduplicates across linear and quad", %{x: x, y: y} do
      quad = Expression.multiply(x, y)
      linear = Expression.from_variable(x)
      result = Expression.add(quad, linear)
      names = Expression.sorted_variables(result) |> Enum.map(& &1.name)
      assert names == ["x", "y"]
    end
  end

  describe "to_string formatting" do
    test "mixed quad + linear + constant", %{x: x, y: y} do
      quad = Expression.multiply(x, y)
      result = Expression.add(Expression.add(quad, Expression.from_variable(x, 2)), 5)
      assert Expression.to_string(result) == "x*y + 2*x + 5"
    end

    test "self-products before cross-products", %{x: x, y: y} do
      xx = Expression.multiply(x, x)
      xy = Expression.multiply(x, y)
      result = Expression.add(xy, xx)
      assert Expression.to_string(result) == "x^2 + x*y"
    end

    test "negative quadratic coefficient", %{x: x} do
      expr = Expression.negate(Expression.multiply(x, x))
      assert Expression.to_string(expr) == "-x^2"
    end
  end
end
