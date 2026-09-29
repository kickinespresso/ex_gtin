defmodule ExGtin.CheckDigitTest do
  @moduledoc """
  Tests for the shared mod-10 check-digit engine (`ExGtin.CheckDigit`).

  These guard the shared check-digit refactor: a property test that `valid?(append(body))` is
  always true, and an equivalence test that the shared engine produces results
  identical to the pre-refactor GTIN implementation
  (`ExGtin.Validation.generate_check_digit/1`) across the existing GTIN test
  vectors.
  """
  use ExUnit.Case
  use ExUnitProperties

  doctest ExGtin.CheckDigit

  alias ExGtin.CheckDigit
  alias ExGtin.Validation

  # The GTIN bodies (without check digit) used across the existing suite.
  # These mirror the vectors in ex_gtin_test.exs / validation_test.exs so the
  # equivalence check is against known-good data.
  @gtin_bodies [
    [1, 2, 3, 3, 1, 2, 3],
    [6, 4, 8, 2, 7, 1, 2, 3, 1, 2, 2],
    [6, 2, 9, 1, 0, 4, 1, 5, 0, 0, 2, 1],
    [2, 2, 3, 1, 2, 3, 1, 2, 2, 3, 1, 2, 3],
    [1, 0, 6, 1, 4, 1, 4, 1, 0, 0, 0, 4, 1]
  ]

  describe "append/1 and valid?/1 (unit)" do
    test "append/1 appends the computed check digit" do
      assert CheckDigit.append([6, 2, 9, 1, 0, 4, 1, 5, 0, 0, 2, 1]) ==
               [6, 2, 9, 1, 0, 4, 1, 5, 0, 0, 2, 1, 3]
    end

    test "valid?/1 accepts a correct check digit" do
      assert CheckDigit.valid?([6, 2, 9, 1, 0, 4, 1, 5, 0, 0, 2, 1, 3])
    end

    test "valid?/1 rejects an incorrect check digit" do
      refute CheckDigit.valid?([6, 2, 9, 1, 0, 4, 1, 5, 0, 0, 2, 1, 4])
    end
  end

  describe "property: append then validate" do
    property "valid?(append(body)) is always true for random digit-list bodies" do
      check all(body <- list_of(integer(0..9), min_length: 1, max_length: 20)) do
        assert CheckDigit.valid?(CheckDigit.append(body))
      end
    end
  end

  describe "equivalence with pre-refactor GTIN implementation" do
    test "mod10/append match Validation.generate_check_digit/1 on GTIN vectors" do
      Enum.each(@gtin_bodies, fn body ->
        expected = Validation.generate_check_digit(body)

        assert CheckDigit.mod10(body) == expected
        assert CheckDigit.append(body) == body ++ [expected]
      end)
    end

    test "appended vectors validate as GTIN codes end-to-end" do
      Enum.each(@gtin_bodies, fn body ->
        code = CheckDigit.append(body)
        assert CheckDigit.valid?(code)
        assert {:ok, "GTIN-#{length(code)}"} == ExGtin.validate(code)
      end)
    end
  end
end
