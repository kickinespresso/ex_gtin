defmodule ExGtin.ParseTest do
  @moduledoc """
  Tests for structured component extraction (`ExGtin.Parse`) and its public
  wiring on `ExGtin.parse/1`.

  A valid code decomposes into `type`, `digits`, `indicator`, `gs1_prefix`,
  `gs1_prefix_region`, `check_digit`, and `valid?`; `indicator` is set only for a
  GTIN-14 and `nil` otherwise; a tampered check digit yields `valid?: false`
  rather than an error; an unknown GS1 prefix maps `gs1_prefix_region` to `nil`;
  no company/item split is attempted (covered by the module docs + doctest); and
  invalid input returns an `{:error, _}` tuple.

  Field values were confirmed against the real check-digit engine and GS1 prefix
  table, so the assertions pin actual behavior rather than hand-computed digits.
  """
  use ExUnit.Case

  doctest ExGtin.Parse

  alias ExGtin.Parse

  describe "field-by-field decomposition of a valid code" do
    test "GTIN-8 exposes every field with indicator nil" do
      assert {:ok, parsed} = Parse.parse("50678907")

      assert parsed == %{
               type: "GTIN-8",
               digits: "50678907",
               indicator: nil,
               gs1_prefix: "506",
               gs1_prefix_region: "GS1 UK",
               check_digit: 7,
               valid?: true
             }
    end

    test "GTIN-12 exposes every field with indicator nil" do
      assert {:ok, parsed} = Parse.parse("012345000058")

      assert parsed == %{
               type: "GTIN-12",
               digits: "012345000058",
               indicator: nil,
               gs1_prefix: "012",
               gs1_prefix_region: "GS1 US",
               check_digit: 8,
               valid?: true
             }
    end

    test "GTIN-13 exposes every field with indicator nil" do
      assert {:ok, parsed} = Parse.parse("6291041500213")

      assert parsed == %{
               type: "GTIN-13",
               digits: "6291041500213",
               indicator: nil,
               gs1_prefix: "629",
               gs1_prefix_region: "GS1 Emirates",
               check_digit: 3,
               valid?: true
             }
    end

    test "GTIN-14 exposes every field and sets the indicator" do
      assert {:ok, parsed} = Parse.parse("10614141000415")

      assert parsed == %{
               type: "GTIN-14",
               digits: "10614141000415",
               indicator: 1,
               gs1_prefix: "106",
               gs1_prefix_region: "GS1 US",
               check_digit: 5,
               valid?: true
             }
    end
  end

  describe "indicator is set only for GTIN-14" do
    test "non-GTIN-14 types have a nil indicator" do
      for code <- ["50678907", "012345000058", "6291041500213"] do
        assert {:ok, %{indicator: nil}} = Parse.parse(code)
      end
    end

    test "a GTIN-14 with indicator 0 reports indicator 0, not nil" do
      # normalize/2 emits a GTIN-14 whose leading digit is the indicator.
      assert {:ok, gtin14} = ExGtin.normalize("6291041500213", 0)
      assert {:ok, %{type: "GTIN-14", indicator: 0}} = Parse.parse(gtin14)
    end
  end

  describe "tampered check digit yields valid?: false, not an error" do
    test "a GTIN-13 with a wrong check digit parses with valid?: false" do
      assert {:ok, parsed} = Parse.parse("6291041500214")

      assert parsed.type == "GTIN-13"
      assert parsed.digits == "6291041500214"
      assert parsed.check_digit == 4
      assert parsed.valid? == false
      # the rest of the fields are still populated from the number
      assert parsed.gs1_prefix == "629"
      assert parsed.gs1_prefix_region == "GS1 Emirates"
    end
  end

  describe "unknown GS1 prefix region maps to nil" do
    test "a valid code with an unassigned prefix pins gs1_prefix_region: nil" do
      # 1621041500213 is a valid GTIN-13 whose 162 prefix is not in the table.
      assert {:ok, parsed} = Parse.parse("1621041500213")

      assert parsed.valid? == true
      assert parsed.gs1_prefix == "162"
      assert parsed.gs1_prefix_region == nil
    end
  end

  describe "String, integer, and digit-list inputs agree" do
    test "the same GTIN-13 parses identically across input shapes" do
      {:ok, from_string} = Parse.parse("6291041500213")
      {:ok, from_integer} = Parse.parse(6_291_041_500_213)
      {:ok, from_list} = Parse.parse([6, 2, 9, 1, 0, 4, 1, 5, 0, 0, 2, 1, 3])

      assert from_string == from_integer
      assert from_string == from_list
    end
  end

  describe "invalid input returns an error tuple" do
    test "a wrong-length code is rejected" do
      assert {:error, _} = Parse.parse("12345")
    end

    test "non-digit characters are rejected" do
      assert {:error, _} = Parse.parse("629104150021a")
    end

    test "an empty string is rejected" do
      assert {:error, _} = Parse.parse("")
    end
  end

  describe "public ExGtin.parse/1 wiring" do
    test "delegates to ExGtin.Parse.parse/1 for a valid code" do
      assert ExGtin.parse("6291041500213") == Parse.parse("6291041500213")
    end

    test "surfaces valid?: false for a tampered code" do
      assert {:ok, %{valid?: false}} = ExGtin.parse("6291041500214")
    end

    test "surfaces an error for invalid input" do
      assert {:error, _} = ExGtin.parse("12345")
    end
  end
end
