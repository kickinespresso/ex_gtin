defmodule ExGtinTest do
  use ExUnit.Case
  doctest ExGtin
  import ExGtin

  test "gtin_check_digit function with valid number string" do
    number = "6291041500213"
    assert {:ok} == check_gtin(number)
  end

  test "gtin_check_digit function with valid number array" do
    number = [6,2,9,1,0,4,1,5,0,0,2,1,3]
    assert {:ok} == check_gtin(number)
  end

  test "gtin_check_digit function with valid number " do
    number = 6291041500213
    assert {:ok} == check_gtin(number)
  end

  test "gtin_check_digit function with invalid number" do
    number = "6291041500214"
    assert {:error} == check_gtin(number)
    assert {:error} == check_gtin("6291041533213")
  end

end
