defmodule ExGtin.GS1.AITableTest do
  @moduledoc """
  Tests for the GS1 Application Identifier dictionary (`ExGtin.GS1.AITable`).

  The AI dictionary is maintained as static data mapping each supported AI code
  to its name, kind, and data format; the initial AI set — 01, 10, 11, 13, 15,
  17, 21, and the 3xx weight AIs — is present; fixed-length AIs record their
  exact data length via `{:fixed, len}`; and variable-length AIs record their
  maximum length via `{:variable, max_len}`.
  """
  use ExUnit.Case

  doctest ExGtin.GS1.AITable

  alias ExGtin.GS1.AITable

  # The base (non-3xx) AIs with their expected {name, kind, format}, per the
  # design's initial AI set.
  @base_ais %{
    "01" => {"GTIN", {:fixed, 14}, :numeric},
    "10" => {"Batch/Lot Number", {:variable, 20}, :alphanumeric},
    "11" => {"Production Date", {:fixed, 6}, :date},
    "13" => {"Packaging Date", {:fixed, 6}, :date},
    "15" => {"Best Before Date", {:fixed, 6}, :date},
    "17" => {"Expiration Date", {:fixed, 6}, :date},
    "21" => {"Serial Number", {:variable, 20}, :alphanumeric}
  }

  # Each 3xx weight family: the three-digit prefix and its human-readable name.
  # Each family expands to six concrete AIs across decimal indicators 0..5.
  @weight_families %{
    "310" => "Net Weight (kg)",
    "320" => "Net Weight (lb)",
    "330" => "Gross Weight (kg)",
    "340" => "Gross Weight (lb)",
    "356" => "Net Weight (troy ounce)"
  }

  @decimal_indicators 0..5

  describe "AI dictionary is maintained as static data" do
    test "ai_table/0 returns a map of AI code to {name, kind, format}" do
      table = AITable.ai_table()

      assert is_map(table)
      refute Enum.empty?(table)

      for {code, entry} <- table do
        assert is_binary(code)

        assert {name, kind, format} = entry
        assert is_binary(name)
        assert is_atom(format)

        case kind do
          {:fixed, len} -> assert is_integer(len) and len > 0
          {:variable, max} -> assert is_integer(max) and max > 0
        end
      end
    end
  end

  describe "the initial base AI set is present with expected kind and length" do
    for {code, expected} <- @base_ais do
      test "AI #{code} is present with the expected entry" do
        assert {:ok, unquote(Macro.escape(expected))} = AITable.lookup(unquote(code))
      end
    end
  end

  describe "fixed-length AIs record their exact data length" do
    test "AI 01 (GTIN) is fixed at 14" do
      assert {:ok, {_, {:fixed, 14}, _}} = AITable.lookup("01")
    end

    test "date AIs (11, 13, 15, 17) are fixed at 6" do
      for code <- ["11", "13", "15", "17"] do
        assert {:ok, {_, {:fixed, 6}, :date}} = AITable.lookup(code)
      end
    end
  end

  describe "variable-length AIs record their maximum length" do
    test "AI 10 (Batch/Lot) and AI 21 (Serial) are variable up to 20" do
      for code <- ["10", "21"] do
        assert {:ok, {_, {:variable, 20}, :alphanumeric}} = AITable.lookup(code)
      end
    end
  end

  describe "the 3xx weight AIs are present with expected kind and length" do
    for {prefix, name} <- @weight_families do
      for d <- @decimal_indicators do
        code = "#{prefix}#{d}"

        test "weight AI #{code} (#{name}) is fixed at 6 numeric" do
          assert {:ok, {unquote(name), {:fixed, 6}, :numeric}} =
                   AITable.lookup(unquote(code))
        end
      end
    end

    test "each weight family expands to exactly six AIs (decimal indicators 0..5)" do
      table = AITable.ai_table()

      for {prefix, _name} <- @weight_families do
        present =
          for d <- @decimal_indicators, Map.has_key?(table, "#{prefix}#{d}"), do: d

        assert Enum.sort(present) == Enum.to_list(@decimal_indicators)
      end
    end
  end

  describe "the full initial AI set count" do
    test "the table holds the 7 base AIs plus 30 weight AIs (37 total)" do
      table = AITable.ai_table()
      assert map_size(table) == map_size(@base_ais) + 5 * Enum.count(@decimal_indicators)
      assert map_size(table) == 37
    end
  end

  describe "unknown AIs are not present" do
    test "lookup/1 returns :error for an unsupported AI code" do
      assert AITable.lookup("99") == :error
    end
  end
end
