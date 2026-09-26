defmodule ExGtin.Convert.GTIN14IndicatorTest do
  @moduledoc """
  Tests for the configurable GTIN-14 indicator digit (F2) on `ExGtin.normalize/2`.

  Covers Requirement 3: `normalize/2` accepts an indicator in `0..9` that
  becomes the leading digit of the emitted GTIN-14 (with a recomputed check
  digit); `normalize/1` behaves exactly as before (indicator `1`); an
  out-of-range indicator returns `{:error, _}`; and the output validates as a
  GTIN-14.

  Validity is confirmed with `ExGtin.validate/1` rather than hardcoding check
  digits, so the tests exercise the real check-digit engine end to end.
  """
  use ExUnit.Case

  import ExGtin

  # A representative GTIN-13 base used to exercise each indicator digit.
  @base "6291041500213"

  describe "each indicator 0..9 yields a valid GTIN-14 with matching first digit" do
    # **Validates: Requirements 3.1, 3.3, 3.5**
    for indicator <- 0..9 do
      test "indicator #{indicator} produces a valid 14-digit GTIN-14" do
        assert {:ok, code} = normalize(@base, unquote(indicator))

        # 14 digits, all numeric
        assert String.length(code) == 14
        assert code =~ ~r/^\d{14}$/

        # first digit equals the requested indicator
        assert String.first(code) == Integer.to_string(unquote(indicator))

        # the emitted code validates as a GTIN-14 (recomputed check digit)
        assert ExGtin.validate(code) == {:ok, "GTIN-14"}
      end
    end
  end

  describe "normalize/1 default is unchanged (regression)" do
    # **Validates: Requirements 3.2**
    test "GTIN-13 default matches the pre-feature output" do
      assert normalize(@base) == {:ok, "16291041500210"}
    end

    test "GTIN-8 default matches the pre-feature output" do
      assert normalize("40170725") == {:ok, "10000040170722"}
    end

    test "GTIN-12 default matches the pre-feature output" do
      assert normalize("840030222641") == {:ok, "10840030222648"}
    end

    test "ISBN-10 default preserves the Bookland leading zero" do
      assert normalize("0205080057") == {:ok, "09780205080052"}
    end

    test "normalize/1 equals normalize/2 with the default indicator 1" do
      assert normalize(@base) == normalize(@base, 1)
    end
  end

  describe "out-of-range indicator returns an error" do
    # **Validates: Requirements 3.4**
    test "indicator above the range is rejected" do
      assert {:error, _} = normalize(@base, 10)
    end

    test "negative indicator is rejected" do
      assert {:error, _} = normalize(@base, -1)
    end

    test "the error message names the valid range" do
      assert normalize(@base, 10) == {:error, "Invalid indicator digit; must be in 0..9"}
    end
  end
end
