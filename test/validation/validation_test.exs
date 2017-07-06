defmodule ExGtin.ValidationTest do
  use ExUnit.Case
  doctest ExGtin.Validation
  import ExGtin.Validation

  # @valid_gtin_codes_atoms %{
  #  codes: [
  #     {code_type: :gtin_8, code: "12331239"},
  #     {code_type: :gtin_12, code: "648271231220"},
  #     {code_type: :gtin_13, code: "6291041500213"},
  #     {code_type: :gtin_14, code: "22312312231235"}
  #   ]
  #  }

   @valid_gtin_codes_arrays %{
     codes: [
       [1,2,3,3,1,2,3,9],
       [6,4,8,2,7,1,2,3,1,2,2,0],
       [6,2,9,1,0,4,1,5,0,0,2,1,3],
       [2,2,3,1,2,3,1,2,2,3,1,2,3,5],
    ]
  }

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

  test "generate_check_digit function" do
    number = [6,2,9,1,0,4,1,5,0,0,2,1]
    assert 3 == generate_check_digit(number)
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

  test "generate_check_code_length function with valid codes" do
    codes = [
      [1,2,3,4,5,6,7],
      [1,2,3,4,5,6,7,8,9,10,11],
      [1,2,3,4,5,6,7,8,9,10,11,12],
      [1,2,3,4,5,6,7,8,9,10,11,12,13]
    ]

    Enum.map(codes, fn(x) -> assert {:ok, "GTIN-#{length(x) + 1}"} == generate_check_code_length(x) end)
  end

  test "generate_check_code_length function with invalid code" do
    code = [1,2,3,4,5,6]
    assert {:error, _} = generate_check_code_length(code)
  end

  test "generate_gtin_code function with valid number string" do
    number = "629104150021"
    assert "6291041500213" == generate_gtin_code(number)
  end

  test "generate_gtin_code function with valid number array" do
    number = [6,2,9,1,0,4,1,5,0,0,2,1]
    assert "6291041500213" == generate_gtin_code(number)
  end

  test "generate_gtin_code function with valid number " do
    number = 629104150021
    assert "6291041500213" == generate_gtin_code(number)
  end
end
