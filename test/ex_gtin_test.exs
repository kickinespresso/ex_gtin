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
      assert {:error, "Invalid Code"} == validate(" 6291041500213 ")
      assert {:error, "Invalid Code"} == validate("\t6291041500213\t")
    end

    test "with non-numeric characters" do
      assert {:error, "Invalid Code"} == validate("629104150021a")
      assert {:error, "Invalid Code"} == validate("629104150021!")
    end

    test "with empty string" do
      assert {:error, "Invalid GTIN Code Length"} == validate("")
    end

    test "with very large numbers" do
      assert {:error, "Invalid GTIN Code Length"} == validate("999999999999999999999999999999")
    end

    test "with negative numbers" do
      assert {:error, "Invalid Code"} == validate("-6291041500213")
    end

    test "with decimal numbers" do
      assert {:error, "Invalid Code"} == validate("629104150021.3")
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
      assert {:error, "Invalid Code"} == generate(" 629104150021 ")
    end

    test "with non-numeric characters" do
      assert {:error, "Invalid Code"} == generate("629104150021a")
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
      assert {:error, "Invalid Code"} == normalize("401-707-25")
      assert {:error, "Invalid Code"} == normalize("401 707 25")
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

  # Requirement 5 — public element-string parsing API (F10). The parse_gs1
  # doctests in lib/ex_gtin.ex are already exercised by the `doctest ExGtin`
  # declaration above; these unit tests cover the behaviours that back
  # requirements 5.1–5.4 through the public entry points.
  @valid_embedded_gtin "06291041500213"
  @gs <<29>>

  describe "parse_gs1/1 mixed payloads (5.1)" do
    test "parenthesized payload with multiple AIs parses to the expected map" do
      assert {:ok, %{"01" => @valid_embedded_gtin, "17" => "261231", "10" => "ABC123"}} ==
               parse_gs1("(01)06291041500213(17)261231(10)ABC123")
    end

    test "raw FNC1 payload with multiple AIs parses to the expected map" do
      payload = "010629104150021310ABC123" <> @gs <> "21XYZ789"

      assert {:ok, %{"01" => @valid_embedded_gtin, "10" => "ABC123", "21" => "XYZ789"}} ==
               parse_gs1(payload)
    end

    test "a payload mixing a GTIN and a 3xx weight AI parses" do
      assert {:ok, %{"01" => @valid_embedded_gtin, "3103" => "000123"}} ==
               parse_gs1("(01)06291041500213(3103)000123")
    end
  end

  describe "parse_gs1/1 accepts both forms through one entry point (5.2)" do
    test "parenthesized and raw forms of the same payload produce equal maps" do
      parenthesized = parse_gs1("(01)06291041500213(10)ABC123")
      raw = parse_gs1("010629104150021310ABC123")

      assert {:ok, %{"01" => @valid_embedded_gtin, "10" => "ABC123"}} == parenthesized
      assert parenthesized == raw
    end
  end

  describe "parse_gs1/1 surfaces the unparsed remainder (5.3)" do
    test "a trailing unknown AI is reported as the unparsed remainder" do
      assert {:ok, %{"01" => @valid_embedded_gtin}, "(99)ABC"} ==
               parse_gs1("(01)06291041500213(99)ABC")
    end
  end

  describe "parse_gs1/1 errors on an unsupported AI at the start (5.4)" do
    test "an unknown AI at position 0 errors with the code and position" do
      assert {:error, {:unknown_ai, "99", 0}} == parse_gs1("(99)ABC")
    end
  end

  describe "parse_gs1/2 date interpretation option" do
    test "dates: :parsed interprets a date AI into a Date struct" do
      assert {:ok, %{"01" => @valid_embedded_gtin, "17" => ~D[2026-12-31]}} ==
               parse_gs1("(01)06291041500213(17)261231", dates: :parsed)
    end

    test "the default leaves date AIs as the raw YYMMDD string" do
      assert {:ok, %{"01" => @valid_embedded_gtin, "17" => "261231"}} ==
               parse_gs1("(01)06291041500213(17)261231")
    end
  end

  describe "parse_gs1!/1" do
    test "returns the parsed map on a full parse" do
      assert %{"01" => @valid_embedded_gtin, "10" => "ABC123"} ==
               parse_gs1!("(01)06291041500213(10)ABC123")
    end

    test "returns a {map, unparsed} tuple on a partial parse without raising" do
      assert {%{"01" => @valid_embedded_gtin}, "(99)ABC"} ==
               parse_gs1!("(01)06291041500213(99)ABC")
    end

    test "raises ArgumentError on a hard error" do
      assert_raise ArgumentError, fn -> parse_gs1!("(99)ABC") end
    end
  end

  # Requirement 8 — public RCN parsing API (F11). The parse_rcn/2 and
  # parse_rcn!/2 doctests in lib/ex_gtin.ex are already exercised by the
  # `doctest ExGtin` declaration above; these unit tests cover the behaviours
  # that back requirements 8.1–8.3 through the public entry points, including a
  # fixture per shipped scheme.
  @germany_price_fixture "2123451789012"
  @embedded_weight_fixture "2456789012349"

  describe "parse_rcn/2 fixtures per shipped scheme (8.2)" do
    test ":gs1_germany_price decodes the price fixture" do
      assert {:ok, %{item: "12345", embedded: %{price: "78901"}}} ==
               parse_rcn(@germany_price_fixture, :gs1_germany_price)
    end

    test ":gs1_embedded_weight decodes the weight fixture" do
      assert {:ok, %{item: "456789", embedded: %{weight: "01234"}}} ==
               parse_rcn(@embedded_weight_fixture, :gs1_embedded_weight)
    end
  end

  describe "parse_rcn/2 accepts a scheme map (8.1)" do
    test "an explicit scheme map decodes the same as its named equivalent" do
      scheme = %{prefix: ["2"], item: 2..6, embedded: {:price, 8..12}, check: nil}

      assert {:ok, %{item: "12345", embedded: %{price: "78901"}}} ==
               parse_rcn(@germany_price_fixture, scheme)
    end
  end

  describe "parse_rcn/2 errors on unknown prefix or scheme (8.3)" do
    test "a non-RCN / wrong-prefix code errors against a shipped scheme" do
      assert {:error, _reason} = parse_rcn("6291041500213", :gs1_germany_price)
    end

    test "an unknown scheme atom errors" do
      assert {:error, "Unknown RCN scheme: :no_such_scheme"} ==
               parse_rcn(@germany_price_fixture, :no_such_scheme)
    end
  end

  describe "parse_rcn!/2" do
    test "returns the decoded map on success" do
      assert %{item: "12345", embedded: %{price: "78901"}} ==
               parse_rcn!(@germany_price_fixture, :gs1_germany_price)
    end

    test "raises ArgumentError on error" do
      assert_raise ArgumentError, fn ->
        parse_rcn!(@germany_price_fixture, :no_such_scheme)
      end
    end
  end
end
