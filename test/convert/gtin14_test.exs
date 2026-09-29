defmodule ExGtin.Convert.GTIN14Test do
  @moduledoc """
  Tests for GTIN-14 down-conversion (`ExGtin.Convert.GTIN14`) and its public
  wiring on `ExGtin`.

  A GTIN-14 with indicator `0` reduces to its base GTIN-13 by stripping the
  leading zero without recomputing the check digit; an indicator in `1..9`
  errors; `to_gtin12/1` additionally strips the next leading zero and
  re-validates as a GTIN-12; the round-trip `to_gtin13(normalize(x, 0)) == {:ok, x}`
  holds; and every successful result validates as `GTIN-13` or `GTIN-12`.

  Validity is confirmed with `ExGtin.validate/1` rather than hardcoding check
  digits, so the tests exercise the real check-digit engine end to end.
  """
  use ExUnit.Case

  doctest ExGtin.Convert.GTIN14

  alias ExGtin.Convert.GTIN14

  # Representative valid GTIN-13 bases used to exercise the round-trip and the
  # non-zero-indicator error path.
  @gtin13_bases [
    "6291041500213",
    "4006381333931",
    "0012345000058"
  ]

  describe "round-trip to_gtin13(normalize(x, 0)) == {:ok, x}" do
    for base <- @gtin13_bases do
      test "base #{base} round-trips through a GTIN-14 with indicator 0" do
        # sanity: the base is itself a valid GTIN-13
        assert ExGtin.validate(unquote(base)) == {:ok, "GTIN-13"}

        assert {:ok, gtin14} = ExGtin.normalize(unquote(base), 0)
        assert String.first(gtin14) == "0"
        assert ExGtin.validate(gtin14) == {:ok, "GTIN-14"}

        assert ExGtin.to_gtin13(gtin14) == {:ok, unquote(base)}
      end
    end
  end

  describe "indicator 1..9 returns the documented error" do
    for indicator <- 1..9 do
      test "indicator #{indicator} has no base GTIN-13" do
        assert {:ok, gtin14} = ExGtin.normalize("6291041500213", unquote(indicator))
        assert String.first(gtin14) == Integer.to_string(unquote(indicator))

        assert ExGtin.to_gtin13(gtin14) ==
                 {:error, "GTIN-14 indicator is not 0; no base GTIN-13"}

        assert ExGtin.to_gtin12(gtin14) ==
                 {:error, "GTIN-14 indicator is not 0; no base GTIN-13"}
      end
    end
  end

  describe "successful to_gtin13 result validates as GTIN-13" do
    for base <- @gtin13_bases do
      test "base #{base} down-converts to a valid GTIN-13" do
        {:ok, gtin14} = ExGtin.normalize(unquote(base), 0)
        assert {:ok, gtin13} = ExGtin.to_gtin13(gtin14)
        assert String.length(gtin13) == 13
        assert ExGtin.validate(gtin13) == {:ok, "GTIN-13"}
      end
    end
  end

  describe "to_gtin12 down-conversion" do
    # A GTIN-14 with indicator 0 AND a next leading 0 has a base GTIN-12.
    test "indicator 0 with a next leading 0 yields a valid GTIN-12" do
      assert {:ok, gtin12} = GTIN14.to_gtin12("00012345000010")
      assert String.length(gtin12) == 12
      assert ExGtin.validate(gtin12) == {:ok, "GTIN-12"}
      assert gtin12 == "012345000010"
    end

    test "the successful GTIN-12 result validates via ExGtin.validate/1" do
      assert {:ok, gtin12} = ExGtin.to_gtin12("00012345000010")
      assert ExGtin.validate(gtin12) == {:ok, "GTIN-12"}
    end

    # A GTIN-14 with indicator 0 but a next non-zero digit has no base GTIN-12.
    test "indicator 0 with a non-zero next digit has no base GTIN-12" do
      assert ExGtin.to_gtin12("06291041500213") ==
               {:error, "GTIN-14 has no base GTIN-12"}
    end
  end

  describe "raising ! variants" do
    test "to_gtin13!/1 returns the string on success" do
      {:ok, gtin14} = ExGtin.normalize("6291041500213", 0)
      assert ExGtin.to_gtin13!(gtin14) == "6291041500213"
    end

    test "to_gtin13!/1 raises ArgumentError on a non-zero indicator" do
      assert_raise ArgumentError, "GTIN-14 indicator is not 0; no base GTIN-13", fn ->
        ExGtin.to_gtin13!("16291041500210")
      end
    end

    test "to_gtin12!/1 returns the string on success" do
      assert ExGtin.to_gtin12!("00012345000010") == "012345000010"
    end

    test "to_gtin12!/1 raises ArgumentError when no base GTIN-12 exists" do
      assert_raise ArgumentError, "GTIN-14 has no base GTIN-12", fn ->
        ExGtin.to_gtin12!("06291041500213")
      end
    end
  end

  describe "invalid / wrong-length input returns an error" do
    test "wrong-length input is rejected by to_gtin13/1" do
      assert {:error, _} = ExGtin.to_gtin13("123")
    end

    test "wrong-length input is rejected by to_gtin12/1" do
      assert {:error, _} = ExGtin.to_gtin12("123")
    end

    test "a non-GTIN-14 valid code is rejected by to_gtin13/1" do
      # A valid GTIN-13 is not a GTIN-14 and has no indicator to strip.
      assert {:error, _} = ExGtin.to_gtin13("6291041500213")
    end
  end
end
