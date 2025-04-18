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
      [2, 2, 3, 1, 2, 3, 1, 2, 2, 3, 1, 2, 3, 5],
      [1, 0, 6, 1, 4, 1, 4, 1, 0, 0, 0, 4, 1, 5]
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

    test "with valid GTIN-8 number" do
      number = 50_678_907
      assert {:ok, "GTIN-8"} == validate(number)
    end

    test "with valid GTIN-12 number" do
      number = 614_141_000_449
      assert {:ok, "GTIN-12"} == validate(number)
    end

    test "with valid GTIN-13 number" do
      number = 6_291_041_500_213
      assert {:ok, "GTIN-13"} == validate(number)
    end

    test "with valid GTIN-14 number" do
      number = 10_614_141_000_415
      assert {:ok, "GTIN-14"} == validate(number)
    end

    test "with invalid number" do
      number = "6291041500214"
      assert {:error, _} = validate(number)
      assert {:error, "Invalid Code"} == validate("6291041533213")
    end

    test "with whitespace" do
      assert_raise ArgumentError, fn ->
        validate(" 6291041500213 ")
      end

      assert_raise ArgumentError, fn ->
        validate("\t6291041500213\t")
      end
    end

    test "with non-numeric characters" do
      assert_raise ArgumentError, fn ->
        validate("629104150021a")
      end

      assert_raise ArgumentError, fn ->
        validate("629104150021!")
      end
    end

    test "with empty string" do
      assert {:error, "Invalid GTIN Code Length"} == validate("")
    end

    test "with very large numbers" do
      assert {:error, "Invalid GTIN Code Length"} == validate("999999999999999999999999999999")
    end

    test "with negative numbers" do
      assert_raise ArgumentError, fn ->
        validate("-6291041500213")
      end
    end

    test "with decimal numbers" do
      assert_raise ArgumentError, fn ->
        validate("629104150021.3")
      end
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

    test "with whitespace raises exception" do
      assert_raise ArgumentError, fn ->
        validate!(" 6291041500213 ")
      end
    end

    test "with non-numeric characters raises exception" do
      assert_raise ArgumentError, fn ->
        validate!("629104150021a")
      end
    end

    test "with empty string raises exception" do
      assert_raise ArgumentError, fn ->
        validate!("")
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

    test "with whitespace" do
      assert_raise ArgumentError, fn ->
        generate(" 629104150021 ")
      end
    end

    test "with non-numeric characters" do
      assert_raise ArgumentError, fn ->
        generate("629104150021a")
      end
    end

    test "with empty string" do
      assert {:error, "Invalid GTIN Code Length"} == generate("")
    end

    test "with very large numbers" do
      assert {:error, "Invalid GTIN Code Length"} == generate("999999999999999999999999999999")
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

    test "with whitespace raises exception" do
      assert_raise ArgumentError, fn ->
        generate!(" 629104150021 ")
      end
    end

    test "with non-numeric characters raises exception" do
      assert_raise ArgumentError, fn ->
        generate!("629104150021a")
      end
    end

    test "with empty string raises exception" do
      assert_raise ArgumentError, fn ->
        generate!("")
      end
    end
  end

  test "validate all gtin codes" do
    Enum.map(
      @valid_gtin_codes_arrays[:codes],
      fn x ->
        assert {:ok, "GTIN-#{length(x)}"} == validate(x)
      end
    )
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

  describe "normalize/1 function" do
    test "with valid GTIN-8 string" do
      number = "40170725"
      assert {:ok, "10000040170722"} == normalize(number)
    end

    test "with valid ISBN 10 string" do
      number = "0205080057"
      assert {:ok, "09780205080052"} == normalize(number)
    end

    test "with valid GTIN-12 string" do
      number = "840030222641"
      assert {:ok, "10840030222648"} == normalize(number)
    end

    test "with valid GTIN-13 string" do
      number = "0840030222641"
      assert {:ok, "10840030222648"} == normalize(number)
    end

    test "with valid GTIN-14 string" do
      number = "10840030222648"
      assert {:ok, "10840030222648"} == normalize(number)
    end

    test "handles different separator characters" do
      assert_raise ArgumentError, fn ->
        normalize("401-707-25")
      end

      assert_raise ArgumentError, fn ->
        normalize("401 707 25")
      end
    end
  end

  describe "README.md examples" do
    test "with validate/1 with valid number string" do
      number = "6291041500213"
      assert {:ok, "GTIN-13"} == validate(number)
    end

    test "with validate/1 with invalid number string" do
      number = "6291041500214"
      assert {:error, "Invalid Code"} == validate(number)
    end

    test "with validate!/1 with valid number string" do
      number = "6291041500213"
      assert "GTIN-13" == validate!(number)
    end

    test "with validate/1 with array" do
      number = [6, 2, 9, 1, 0, 4, 1, 5, 0, 0, 2, 1, 3]
      assert {:ok, "GTIN-13"} == validate(number)
    end

    test "with validate/1 with number" do
      number = 6_291_041_500_213
      assert {:ok, "GTIN-13"} == validate(number)
    end

    test "with generate/1" do
      number = "629104150021"
      assert {:ok, "6291041500213"} == generate(number)
    end

    test "with generate!/1" do
      number = "629104150021"
      assert "6291041500213" == generate!(number)
    end

    test "with gs1_prefix_country/1" do
      number = "53523235"
      assert {:ok, "GS1 Malta"} == gs1_prefix_country(number)
    end

    test "with normalize/1" do
      assert {:ok, "10000040170722"} == normalize("40170725")
      assert {:ok, "16291041500210"} == normalize("6291041500213")
    end
  end
end
