defmodule ExGtinTest do
  use ExUnit.Case
  doctest ExGtin
  import ExGtin

  test "check_gtin function with valid number string" do
    number = "6291041500213"
    assert {:ok, "GTIN-13"} == check_gtin(number)
  end

  test "check_gtin function with valid number array" do
    number = [6,2,9,1,0,4,1,5,0,0,2,1,3]
    assert {:ok, "GTIN-13"} == check_gtin(number)
  end

  test "check_gtin function with valid number " do
    number = 6291041500213
    assert {:ok, "GTIN-13"} == check_gtin(number)
  end

  test "check_gtin function with invalid number" do
    number = "6291041500214"
    assert {:error, _} = check_gtin(number)
    assert {:error, "Invalid Code"} == check_gtin("6291041533213")
  end

  test "generate_gtin function with valid number string" do
    number = "629104150021"
    assert "6291041500213" == generate_gtin(number)
  end

  test "generate_gtin function with valid number array" do
    number = [6,2,9,1,0,4,1,5,0,0,2,1]
    assert "6291041500213" == generate_gtin(number)
  end

  test "generate_gtin function with valid number " do
    number = 629104150021
    assert "6291041500213" == generate_gtin(number)
  end

end
