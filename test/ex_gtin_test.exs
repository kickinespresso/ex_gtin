defmodule ExGtinTest do
  use ExUnit.Case
  doctest ExGtin
  import ExGtin

  @valid_gtin_codes_arrays %{
    codes: [
      [1, 2, 3, 3, 1, 2, 3, 9],
      [6, 4, 8, 2, 7, 1, 2, 3, 1, 2, 2, 0],
      [6, 2, 9, 1, 0, 4, 1, 5, 0, 0, 2, 1, 3],
      [2, 2, 3, 1, 2, 3, 1, 2, 2, 3, 1, 2, 3, 5],
   ]
 }

  test "check_gtin function with valid number string" do
    number = "6291041500213"
    assert {:ok, "GTIN-13"} == check_gtin(number)
  end

  test "check_gtin function with valid number array" do
    number = [6, 2, 9, 1, 0, 4, 1, 5, 0, 0, 2, 1, 3]
    assert {:ok, "GTIN-13"} == check_gtin(number)
  end

  test "check_gtin function with valid number " do
    number = 6_291_041_500_213
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
    number = [6, 2, 9, 1, 0, 4, 1, 5, 0, 0, 2, 1]
    assert "6291041500213" == generate_gtin(number)
  end

  test "generate_gtin function with valid number " do
    number = 629_104_150_021
    assert "6291041500213" == generate_gtin(number)
  end

  test "validate all gtin codes" do
    Enum.map(@valid_gtin_codes_arrays[:codes],
      fn(x) ->
        assert {:ok, "GTIN-#{length(x)}"} == check_gtin(x)
      end)
  end

  test "gs1_prefix_country function with string" do
    number = "53523235"
    assert {:ok, "GS1 Malta"} == gs1_prefix_country(number)
  end

  test "gs1_prefix_country function with number" do
    number = 53_523_235
    assert {:ok, "GS1 Malta"} == gs1_prefix_country(number)
  end

end
