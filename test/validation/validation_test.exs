defmodule ExGtin.ValidationTest do
  use ExUnit.Case
  doctest ExGtin
  import ExGtin.Validation

  test "gtin_check_digit function with valid number string" do
    number = "6291041500213"
    assert {:ok, "GTIN-13"} == gtin_check_digit(number)
  end

  test "gtin_check_digit function with valid number array" do
    number = [6,2,9,1,0,4,1,5,0,0,2,1,3]
    assert {:ok, "GTIN-13"} == gtin_check_digit(number)
  end

  test "gtin_check_digit function with valid number " do
    number = 6291041500213
    assert {:ok, "GTIN-13"} == gtin_check_digit(number)
  end

  test "gtin_check_digit function with invalid number" do
    number = "6291041500214"
    assert {:error, "Invalid Code"} == gtin_check_digit(number)
    assert {:error, "Invalid Code"} == gtin_check_digit("6291041533213")
  end

  test "gtin_check_digit function with invalid length" do
    number = "62910415002143232232"
    assert {:error, "Invalid GTIN Code Length"} == gtin_check_digit(number)
    assert {:error, _} = gtin_check_digit("62910415002143232232")
  end

  test "mult_by_index_code function" do
    assert mult_by_index_code(1) == 1
    assert mult_by_index_code(2) == 3
    assert mult_by_index_code(3) == 1
    assert mult_by_index_code(4) == 3
  end

  test "multiply_and_sum_array function" do
    number = [6,2,9,1,0,4,1,5,0,0,2,1]
    assert 57 == multiply_and_sum_array(number)
  end

  test "subtract_from_nearest_multiple_of_ten function" do
    assert 3 == subtract_from_nearest_multiple_of_ten(57)
  end

  test "check_code_length function with valid codes" do
    codes = [
      [1,2,3,4,5,6,7,8],
      [1,2,3,4,5,6,7,8,9,10,11,12],
      [1,2,3,4,5,6,7,8,9,10,11,12,13],
      [1,2,3,4,5,6,7,8,9,10,11,12,13,14]
    ]

    Enum.map(codes, fn(x) -> assert {:ok, "GTIN-#{length(x)}"} == check_code_length(x) end)
  end

  test "check_code_length function with invalid code" do
    code = [1,2,3,4,5,6,7]
    assert {:error, _} = check_code_length(code)
  end
end