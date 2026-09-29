defmodule ExGtin.Convert.UPCTest do
  @moduledoc """
  Tests for UPC-E ⇄ UPC-A conversion (`ExGtin.Convert.UPC`).

  Covers: round-trip across all four 6th-digit
  expansion branches for both number systems; rejection of ineligible number
  systems, wrong length, and non-numeric input; the non-compressible UPC-A
  error; the GTIN-12 validity of expanded output; and the raising `!` variants.

  The round-trip vectors are chosen so the UPC-E's trailing digit already equals
  the recomputed UPC-A check digit — the round-trip guarantee
  `upca_to_upce(upce_to_upca(x)) == {:ok, x}` only holds when the input's check
  digit is self-consistent, since `upce_to_upca/1` recomputes it.
  """
  use ExUnit.Case

  doctest ExGtin.Convert.UPC

  alias ExGtin.Convert.UPC

  # {label, upce, expanded upca} — one self-consistent vector per 6th-digit
  # branch, for both number system 0 and 1.
  @roundtrip_vectors [
    # number system 0
    {"ns0 branch {0,1,2}", "01234505", "012000003455"},
    {"ns0 branch 3", "01234531", "012300000451"},
    {"ns0 branch 4", "01234543", "012340000053"},
    {"ns0 branch 5..9", "01234572", "012345000072"},
    # number system 1
    {"ns1 branch {0,1,2}", "11234502", "112000003452"},
    {"ns1 branch 3", "11234538", "112300000458"},
    {"ns1 branch 4", "11234540", "112340000050"},
    {"ns1 branch 5..9", "11234579", "112345000079"}
  ]

  describe "round-trip across all four 6th-digit branches" do
    for {label, upce, upca} <- @roundtrip_vectors do
      test "expands and compresses #{label} exactly" do
        assert UPC.upce_to_upca(unquote(upce)) == {:ok, unquote(upca)}
        assert UPC.upca_to_upce(unquote(upca)) == {:ok, unquote(upce)}
      end

      test "round-trip #{label}: upca_to_upce(upce_to_upca(x)) == {:ok, x}" do
        {:ok, expanded} = UPC.upce_to_upca(unquote(upce))
        assert UPC.upca_to_upce(expanded) == {:ok, unquote(upce)}
      end
    end
  end

  describe "expanded UPC-A validates as GTIN-12" do
    for {label, upce, upca} <- @roundtrip_vectors do
      test "#{label} expands to a valid GTIN-12" do
        assert {:ok, expanded} = UPC.upce_to_upca(unquote(upce))
        assert expanded == unquote(upca)
        assert ExGtin.validate(expanded) == {:ok, "GTIN-12"}
      end
    end
  end

  describe "reject ineligible number system (2–9)" do
    for ns <- 2..9 do
      test "number system #{ns} is rejected" do
        upce = "#{unquote(ns)}1234560"
        assert UPC.upce_to_upca(upce) == {:error, "UPC-E number system must be 0 or 1"}
      end
    end
  end

  describe "reject wrong length / non-numeric input" do
    test "too short is rejected" do
      assert UPC.upce_to_upca("1234567") == {:error, "Invalid UPC-E length"}
    end

    test "too long is rejected" do
      assert UPC.upce_to_upca("012345650") == {:error, "Invalid UPC-E length"}
    end

    test "non-numeric input is rejected" do
      assert UPC.upce_to_upca("0123456a") == {:error, "UPC-E must contain only digits"}
    end

    test "wrong-length UPC-A is rejected" do
      assert UPC.upca_to_upce("12345000065") == {:error, "Invalid UPC-A length"}
    end

    test "non-numeric UPC-A is rejected" do
      assert UPC.upca_to_upce("01234500006x") == {:error, "UPC-A must contain only digits"}
    end
  end

  describe "reject non-compressible UPC-A" do
    test "a UPC-A with no zero-run pattern is not compressible" do
      assert UPC.upca_to_upce("012345678905") ==
               {:error, "UPC-A is not compressible to UPC-E"}
    end
  end

  describe "String, integer, and digit-list inputs" do
    test "digit-list UPC-E expands like the string form" do
      assert UPC.upce_to_upca([0, 1, 2, 3, 4, 5, 0, 5]) == {:ok, "012000003455"}
    end

    test "integer UPC-E (number system 1) expands correctly" do
      assert UPC.upce_to_upca(11_234_502) == {:ok, "112000003452"}
    end

    test "digit-list UPC-A compresses like the string form" do
      assert UPC.upca_to_upce([0, 1, 2, 0, 0, 0, 0, 0, 3, 4, 5, 5]) == {:ok, "01234505"}
    end
  end

  describe "raising ! variants" do
    test "upce_to_upca!/1 returns the string on success" do
      assert ExGtin.upce_to_upca!("01234505") == "012000003455"
    end

    test "upce_to_upca!/1 raises ArgumentError on error" do
      assert_raise ArgumentError, "UPC-E number system must be 0 or 1", fn ->
        ExGtin.upce_to_upca!("21234560")
      end
    end

    test "upca_to_upce!/1 returns the string on success" do
      assert ExGtin.upca_to_upce!("012000003455") == "01234505"
    end

    test "upca_to_upce!/1 raises ArgumentError on error" do
      assert_raise ArgumentError, "UPC-A is not compressible to UPC-E", fn ->
        ExGtin.upca_to_upce!("012345678905")
      end
    end
  end
end
