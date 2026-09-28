defmodule ExGtin.BugFixesTest do
  @moduledoc """
  Regression tests for the issues found in the 1.2.1 code review.

  Each `assert` states the CORRECT (post-fix) behavior, so every test here
  FAILS on the unfixed 1.2.1 code (proving the bug) and PASSES once the
  corresponding fix is applied (validating it).
  """
  use ExUnit.Case
  import ExGtin

  describe "Issue 1: ISBN-10 with 'X' check digit" do
    test "normalize/1 converts a valid ISBN-10 ending in X" do
      # 1.2.1: ** (ArgumentError) not a textual representation of an integer
      assert {:ok, "09781558608320"} == normalize("155860832X")
      assert {:ok, "GTIN-14"} == validate("09781558608320")
    end
  end

  describe "Issue 2: unvalidated 10-character ISBN-10 routing" do
    test "normalize/1 rejects a 10-digit string that is not a valid ISBN-10" do
      # 1.2.1: {:ok, "09781234567897"}
      assert {:error, "Invalid Code"} == normalize("1234567890")
    end

    test "normalize/1 still accepts a genuinely valid ISBN-10" do
      assert {:ok, "09780205080052"} == normalize("0205080057")
    end
  end

  describe "Issue 3: list input to normalize/1" do
    test "normalize/1 accepts a digit list, per its @spec" do
      # 1.2.1: ** (FunctionClauseError)
      assert {:ok, "16291041500210"} == normalize([6, 2, 9, 1, 0, 4, 1, 5, 0, 0, 2, 1, 3])
    end
  end

  describe "Issue 5: float input" do
    test "validate/1 returns a clean error for a float" do
      # 1.2.1: ** (FunctionClauseError) in Integer.digits/2
      assert {:error, "Invalid numeric input"} == validate(6.5)
    end

    test "generate/1 returns a clean error for a float" do
      assert {:error, "Invalid numeric input"} == generate(6.5)
    end
  end

  describe "regression guards — existing behavior must be preserved" do
    test "standard validate / generate / normalize / prefix" do
      assert {:ok, "GTIN-13"} == validate("6291041500213")
      assert {:ok, "6291041500213"} == generate("629104150021")
      assert {:ok, "16291041500210"} == normalize("6291041500213")
      assert {:ok, "10000040170722"} == normalize("40170725")
      assert {:ok, "GS1 Malta"} == gs1_prefix_country("53523235")
    end

    test "malformed 10-char strings return a clean error (separators, letters)" do
      # Non-numeric input now returns {:error, _} instead of raising ArgumentError.
      assert {:error, "Invalid Code"} == normalize("401-707-25")
      assert {:error, "Invalid Code"} == normalize("401 707 25")
    end
  end
end
