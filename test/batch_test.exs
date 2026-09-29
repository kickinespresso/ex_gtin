defmodule ExGtin.BatchTest do
  @moduledoc """
  Tests for batch validation helpers (`ExGtin.Batch`) and their public wiring on
  `ExGtin.validate_all/1` and `ExGtin.partition/1`.

  `validate_all/1` returns a list of
  `{code, {:ok, type} | {:error, reason}}` tuples preserving input order;
  `partition/1` splits inputs into `%{valid: [...], invalid: [...]}`; an empty
  list yields an empty result without raising; and an invalid item is captured
  as an error rather than raising, across a variety of bad inputs — wrong
  length, non-digit, and a tampered check digit.

  Known fixtures: "6291041500213" -> {:ok, "GTIN-13"} and "6291041500214"
  (tampered check digit) -> {:error, "Invalid Code"}, confirmed against
  `ExGtin.validate/1`.
  """
  use ExUnit.Case

  doctest ExGtin.Batch

  alias ExGtin.Batch

  # A spread of invalid inputs that must never raise:
  # wrong length, non-digit characters, and a tampered check digit.
  @bad_inputs ["12345", "629104150021a", "6291041500214"]

  describe "validate_all/1 pairs each input with its result" do
    test "a mixed list pairs each code with its validate/1 result" do
      assert Batch.validate_all(["6291041500213", "6291041500214"]) == [
               {"6291041500213", {:ok, "GTIN-13"}},
               {"6291041500214", {:error, "Invalid Code"}}
             ]
    end

    test "input order is preserved" do
      codes = ["6291041500214", "6291041500213", "12345", "6291041500213"]

      assert Batch.validate_all(codes) |> Enum.map(fn {code, _} -> code end) ==
               codes
    end

    test "each pairing matches a direct validate/1 call" do
      codes = ["6291041500213", "6291041500214", "12345"]

      for {code, result} <- Batch.validate_all(codes) do
        assert result == ExGtin.validate(code)
      end
    end
  end

  describe "partition/1 splits into valid and invalid buckets" do
    test "a mixed list is split into valid and invalid" do
      assert Batch.partition(["6291041500213", "6291041500214"]) ==
               %{valid: ["6291041500213"], invalid: ["6291041500214"]}
    end

    test "order is preserved within each bucket" do
      codes = [
        "6291041500214",
        "6291041500213",
        "12345",
        "6291041500213",
        "629104150021a"
      ]

      assert Batch.partition(codes) == %{
               valid: ["6291041500213", "6291041500213"],
               invalid: ["6291041500214", "12345", "629104150021a"]
             }
    end
  end

  describe "empty list yields an empty result without raising" do
    test "validate_all/1 returns []" do
      assert Batch.validate_all([]) == []
    end

    test "partition/1 returns empty buckets" do
      assert Batch.partition([]) == %{valid: [], invalid: []}
    end
  end

  describe "invalid items are captured as errors, not raised" do
    test "validate_all/1 pairs each bad input with an {:error, _} tuple" do
      for {code, result} <- Batch.validate_all(@bad_inputs) do
        assert {:error, _} = result
        assert code in @bad_inputs
      end
    end

    test "partition/1 places every bad input in :invalid" do
      assert Batch.partition(@bad_inputs) ==
               %{valid: [], invalid: @bad_inputs}
    end

    test "a bad item does not abort the batch around valid items" do
      codes = ["6291041500213" | @bad_inputs] ++ ["6291041500213"]

      assert Batch.partition(codes) == %{
               valid: ["6291041500213", "6291041500213"],
               invalid: @bad_inputs
             }
    end
  end

  describe "public ExGtin.validate_all/1 wiring" do
    test "delegates to ExGtin.Batch.validate_all/1" do
      codes = ["6291041500213", "6291041500214", "12345"]
      assert ExGtin.validate_all(codes) == Batch.validate_all(codes)
    end

    test "returns [] for an empty list" do
      assert ExGtin.validate_all([]) == []
    end
  end

  describe "public ExGtin.partition/1 wiring" do
    test "delegates to ExGtin.Batch.partition/1" do
      codes = ["6291041500213", "6291041500214", "12345"]
      assert ExGtin.partition(codes) == Batch.partition(codes)
    end

    test "returns empty buckets for an empty list" do
      assert ExGtin.partition([]) == %{valid: [], invalid: []}
    end
  end
end
