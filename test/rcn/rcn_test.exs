defmodule ExGtin.RCNTest do
  @moduledoc """
  Tests for restricted-circulation number (RCN) prefix recognition
  (`ExGtin.RCN`).

  A code carrying an RCN prefix (`02` or `20`–`29`) is recognized as a
  restricted-circulation number; a code without an RCN prefix returns an
  `{:error, _}` tuple from the RCN recognizer; and recognition stays consistent
  with the leading-three-digit ranges the existing GS1 prefix table already
  flags — `020`–`029` and `200`–`299`.
  """
  use ExUnit.Case

  doctest ExGtin.RCN
  doctest ExGtin.RCN.Schemes

  alias ExGtin.RCN
  alias ExGtin.RCN.Schemes

  describe "RCN prefixes are recognized" do
    test "the 02 prefix (020-029 range) is recognized as an RCN" do
      code = "0201234500002"
      assert {:ok, ^code} = RCN.recognize(code)
      assert {:ok, true} = RCN.rcn_prefix?(code)
    end

    test "the 20 prefix (start of 200-299 range) is recognized as an RCN" do
      code = "2001234500009"
      assert {:ok, ^code} = RCN.recognize(code)
      assert {:ok, true} = RCN.rcn_prefix?(code)
    end

    test "a mid-range prefix (259) is recognized as an RCN" do
      code = "2591234500004"
      assert {:ok, ^code} = RCN.recognize(code)
      assert {:ok, true} = RCN.rcn_prefix?(code)
    end

    test "recognition accepts a non-negative integer input" do
      code = 2_001_234_500_009
      assert {:ok, ^code} = RCN.recognize(code)
      assert {:ok, true} = RCN.rcn_prefix?(code)
    end

    test "recognition accepts a list-of-digits input" do
      code = [2, 0, 0, 1, 2, 3, 4, 5, 0, 0, 0, 0, 9]
      assert {:ok, ^code} = RCN.recognize(code)
      assert {:ok, true} = RCN.rcn_prefix?(code)
    end
  end

  describe "non-RCN codes are rejected" do
    test "a normal GTIN errors from recognize/1 and is false from rcn_prefix?/1" do
      code = "6291041500213"
      assert {:error, _reason} = RCN.recognize(code)
      assert {:ok, false} = RCN.rcn_prefix?(code)
    end

    test "030 (GS1 US, just past the 020-029 range) is not an RCN" do
      code = "0301234500001"
      assert {:error, _reason} = RCN.recognize(code)
      assert {:ok, false} = RCN.rcn_prefix?(code)
    end

    test "199 (just below the 200-299 range) is not an RCN" do
      code = "1991234500002"
      assert {:error, _reason} = RCN.recognize(code)
      assert {:ok, false} = RCN.rcn_prefix?(code)
    end

    test "300 (GS1 France, just past the 200-299 range) is not an RCN" do
      code = "3001234500005"
      assert {:error, _reason} = RCN.recognize(code)
      assert {:ok, false} = RCN.rcn_prefix?(code)
    end
  end

  describe "malformed input errors" do
    test "a code with non-digit characters errors" do
      code = "20A1234500009"
      assert {:error, _reason} = RCN.recognize(code)
      assert {:error, _reason} = RCN.rcn_prefix?(code)
    end

    test "a code too short to carry a prefix errors" do
      code = "12"
      assert {:error, _reason} = RCN.recognize(code)
      assert {:error, _reason} = RCN.rcn_prefix?(code)
    end

    test "a negative integer errors" do
      code = -2_001_234_500_009
      assert {:error, _reason} = RCN.recognize(code)
      assert {:error, _reason} = RCN.rcn_prefix?(code)
    end
  end

  describe "scheme-driven decoding" do
    # Digit positions for "2123451789012":
    #   pos:  1 2 3 4 5 6 7 8 9 10 11 12 13
    #   dig:  2 1 2 3 4 5 1 7 8 9  0  1  2
    #
    # Position 7 (`1`) is the :gs1_germany_price internal price check digit: the
    # GS1 mod-10 check digit over the embedded price field (positions 8..12 =
    # 7,8,9,0,1), which is 1. Using the correct check digit lets this fixture
    # decode cleanly under the price scheme; item ref is 12345, price is 78901.
    @germany_code "2123451789012"

    test "a price scheme extracts item and embedded price under :price" do
      assert {:ok, %{item: "12345", embedded: %{price: "78901"}}} =
               RCN.decode(@germany_code, :gs1_germany_price)
    end

    test "a weight scheme extracts item and embedded weight under :weight" do
      assert {:ok, %{item: "123451", embedded: %{weight: "78901"}}} =
               RCN.decode(@germany_code, :gs1_embedded_weight)
    end

    test "a named atom scheme and its resolved map produce the same result" do
      {:ok, scheme_map} = Schemes.fetch(:gs1_germany_price)

      assert RCN.decode(@germany_code, :gs1_germany_price) ==
               RCN.decode(@germany_code, scheme_map)
    end

    test "an explicit scheme map is accepted directly" do
      scheme = %{prefix: ["2"], item: 2..6, embedded: {:price, 8..12}, check: nil}

      assert {:ok, %{item: "12345", embedded: %{price: "78901"}}} =
               RCN.decode(@germany_code, scheme)
    end

    test "leading zeros in the extracted fields are preserved" do
      # pos 8..12 here are 0,0,0,0,5 -> "00005"
      scheme = %{prefix: ["2"], item: 2..7, embedded: {:weight, 8..12}, check: nil}

      assert {:ok, %{item: "012345", embedded: %{weight: "00005"}}} =
               RCN.decode("2012345000053", scheme)
    end

    test "an integer code is normalized and decoded" do
      assert {:ok, %{item: "12345", embedded: %{price: "78901"}}} =
               RCN.decode(2_123_451_789_012, :gs1_germany_price)
    end

    test "a list-of-digits code is normalized and decoded" do
      code = [2, 1, 2, 3, 4, 5, 1, 7, 8, 9, 0, 1, 2]

      assert {:ok, %{item: "12345", embedded: %{price: "78901"}}} =
               RCN.decode(code, :gs1_germany_price)
    end

    # A dedicated weight fixture decoded under the shipped :gs1_embedded_weight
    # scheme (prefix "2", item positions 2..7, weight positions 8..12, no
    # internal check digit).
    #   pos:  1 2 3 4 5 6 7 8 9 10 11 12 13
    #   dig:  2 4 5 6 7 8 9 0 1 2  3  4  9
    # item ref is positions 2..7 = "456789"; embedded weight is positions
    # 8..12 = "01234".
    @weight_code "2456789012349"

    test "the shipped :gs1_embedded_weight scheme decodes a weight fixture to %{weight: ...}" do
      assert {:ok, %{item: "456789", embedded: %{weight: "01234"}}} =
               RCN.decode(@weight_code, :gs1_embedded_weight)
    end

    test "an unknown scheme atom errors" do
      assert {:error, _reason} = RCN.decode(@germany_code, :no_such_scheme)
    end

    test "a wrong-length code errors" do
      assert {:error, _reason} = RCN.decode("21234", :gs1_germany_price)
    end

    test "a non-digit code errors" do
      assert {:error, _reason} = RCN.decode("21234A6789012", :gs1_germany_price)
    end
  end

  describe "internal price check-digit validation" do
    # For the :gs1_germany_price scheme the internal check digit at position 7
    # is the GS1 mod-10 check digit over the embedded price field (positions
    # 8..12). "2123451789012" carries the correct digit (1); "2123456789012"
    # carries a wrong one (6).

    test "a code with the correct internal check digit decodes" do
      assert {:ok, %{item: "12345", embedded: %{price: "78901"}}} =
               RCN.decode("2123451789012", :gs1_germany_price)
    end

    test "a code with a mismatched internal check digit errors" do
      assert {:error, "Invalid internal price check digit"} =
               RCN.decode("2123456789012", :gs1_germany_price)
    end

    test "a scheme with check: nil skips internal check-digit validation" do
      # Same code that fails under :gs1_germany_price decodes fine when the
      # scheme declares no internal check digit.
      scheme = %{prefix: ["2"], item: 2..6, embedded: {:price, 8..12}, check: nil}

      assert {:ok, %{item: "12345", embedded: %{price: "78901"}}} =
               RCN.decode("2123456789012", scheme)
    end

    test "the internal check digit is validated for an integer code too" do
      assert {:error, "Invalid internal price check digit"} =
               RCN.decode(2_123_456_789_012, :gs1_germany_price)
    end
  end

  describe "scheme/prefix mismatch" do
    test "a code whose prefix is not listed in the scheme errors" do
      # Scheme applies only to prefix "3"; the code starts with "2".
      scheme = %{prefix: ["3"], item: 2..6, embedded: {:price, 8..12}, check: nil}

      assert {:error, "Code prefix does not match scheme"} =
               RCN.decode("2123451789012", scheme)
    end

    test "the shipped price scheme rejects a non-2 prefix code" do
      # "3123451789013" is a 13-digit code on prefix "3", outside the scheme.
      assert {:error, "Code prefix does not match scheme"} =
               RCN.decode("3123451789013", :gs1_germany_price)
    end
  end
end
