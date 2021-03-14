defmodule ExGtinTest do
  @moduledoc """
  Library Tests
  """
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

   describe "validate/1 function" do
    test "with valid number string" do
      number = "6291041500213"
      assert {:ok, "GTIN-13"} == validate(number)
    end

    test "with valid number array" do
      number = [6, 2, 9, 1, 0, 4, 1, 5, 0, 0, 2, 1, 3]
      assert {:ok, "GTIN-13"} == validate(number)
    end

    test "with valid number " do
      number = 6_291_041_500_213
      assert {:ok, "GTIN-13"} == validate(number)
    end

    test "with invalid number" do
      number = "6291041500214"
      assert {:error, _} = validate(number)
      assert {:error, "Invalid Code"} == validate("6291041533213")
    end
  end

   describe "validate!/1 function" do
    test "with valid number string" do
      number = "6291041500213"
      assert "GTIN-13" == validate!(number)
    end

    test "with valid number array" do
      number = [6, 2, 9, 1, 0, 4, 1, 5, 0, 0, 2, 1, 3]
      assert "GTIN-13" == validate!(number)
    end

    test "with valid number " do
      number = 6_291_041_500_213
      assert "GTIN-13" == validate!(number)
    end

    test "with invalid number, raises exception" do
      number = "6291041500214"
      assert_raise ArgumentError, fn ->
        validate!(number)
      end
       assert_raise ArgumentError, fn ->
         validate!("6291041533213")
      end
    end
  end

  describe "generate/1 function" do
    test "with valid number string" do
      number = "629104150021"
      assert {:ok, "6291041500213"} == generate(number)
    end

    test "with valid number array" do
      number = [6, 2, 9, 1, 0, 4, 1, 5, 0, 0, 2, 1]
      assert {:ok, "6291041500213"} == generate(number)
    end

    test "with valid number " do
      number = 629_104_150_021
      assert {:ok, "6291041500213"} == generate(number)
    end
  end

  describe "generate!/1 function" do
    test "with valid number string" do
      number = "629104150021"
      assert "6291041500213" == generate!(number)
    end

     test "with invalid number, raises exception" do
      assert_raise ArgumentError, fn ->
        number = "62921"
         IO.puts(generate!(number))
      end
       assert_raise ArgumentError, fn ->
        generate!("62921")
      end
    end

    test "with valid number array" do
      number = [6, 2, 9, 1, 0, 4, 1, 5, 0, 0, 2, 1]
      assert "6291041500213" == generate!(number)
    end

    test "with valid number " do
      number = 629_104_150_021
      assert "6291041500213" == generate!(number)
    end
  end

  test "validate all gtin codes" do
    Enum.map(@valid_gtin_codes_arrays[:codes],
      fn(x) ->
        assert {:ok, "GTIN-#{length(x)}"} == validate(x)
      end)
  end

  describe "gs1_prefix_country function" do
    test "with string" do
      number = "53523235"
      assert {:ok, "GS1 Malta"} == gs1_prefix_country(number)
    end

    test "with number" do
      number = 53_523_235
      assert {:ok, "GS1 Malta"} == gs1_prefix_country(number)
    end
  end

end
