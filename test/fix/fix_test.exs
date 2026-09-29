defmodule ExGtin.FixTest do
  @moduledoc """
  Tests for the best-effort GTIN correction engine (`ExGtin.Fix`).

  The correction contract is deliberately narrow: `fix` only undoes the two
  information-preserving mutations that damage real GTIN data — dropped leading
  zeros and surrounding whitespace — and then re-validates the mod-10 check
  digit. These tests borrow the edge-case discipline of the Rust `gtin-validate`
  crate's `fix` suite: canonical all-zeros vectors, every wrong check digit,
  boundary lengths, non-numeric/non-ASCII inputs, and property-based invariants
  (never crash, and successful output is idempotent and validates).
  """
  use ExUnit.Case
  use ExUnitProperties

  doctest ExGtin.Fix

  alias ExGtin.Fix

  describe "fix/1 zero-padding" do
    test "pads a short numeric string to the smallest fitting GTIN length" do
      # 11 digits -> GTIN-12
      assert Fix.fix("87248795257") == {:ok, "087248795257"}
    end

    test "pads all-zeros to GTIN-8 (the smallest supported length)" do
      assert Fix.fix("0") == {:ok, "00000000"}
    end

    test "a valid 12-digit code infers GTIN-12 (no padding needed)" do
      assert Fix.fix("123012301238") == {:ok, "123012301238"}
    end

    test "a valid 12-digit body can be forced up to GTIN-13 via fix/2" do
      assert Fix.fix("123012301238", 13) == {:ok, "0123012301238"}
    end

    test "an already-valid full-length code is returned unchanged" do
      assert Fix.fix("6291041500213") == {:ok, "6291041500213"}
    end
  end

  describe "fix/1 whitespace trimming" do
    test "trims trailing whitespace" do
      assert Fix.fix("6291041500213 ") == {:ok, "6291041500213"}
    end

    test "trims leading and trailing whitespace, including newlines" do
      assert Fix.fix("  6291041500213\n") == {:ok, "6291041500213"}
    end

    test "trims then zero-pads together" do
      assert Fix.fix(" 87248795257 ") == {:ok, "087248795257"}
    end
  end

  describe "fix/1 errors" do
    test "an input longer than 14 digits is :invalid_length" do
      assert Fix.fix("123412341234123") == {:error, :invalid_length}
    end

    test "a full-length code with a bad check digit is :check_digit_incorrect" do
      assert Fix.fix("123456789013") == {:error, :check_digit_incorrect}
    end

    test "non-numeric strings are :non_numeric" do
      assert Fix.fix("a") == {:error, :non_numeric}
      assert Fix.fix("4.2") == {:error, :non_numeric}
      assert Fix.fix("-1") == {:error, :non_numeric}
      assert Fix.fix("00000000000a") == {:error, :non_numeric}
    end

    test "non-ASCII / multibyte input is :non_numeric, never crashes" do
      assert Fix.fix("❤") == {:error, :non_numeric}
      assert Fix.fix("６２９") == {:error, :non_numeric}
    end

    test "an empty or whitespace-only string is :non_numeric" do
      assert Fix.fix("") == {:error, :non_numeric}
      assert Fix.fix("   ") == {:error, :non_numeric}
    end
  end

  describe "fix/1 accepts integer and digit-list inputs" do
    test "a non-negative integer is stringified then padded" do
      assert Fix.fix(87_248_795_257) == {:ok, "087248795257"}
    end

    test "a digit list is joined then padded" do
      assert Fix.fix([8, 7, 2, 4, 8, 7, 9, 5, 2, 5, 7]) == {:ok, "087248795257"}
    end

    test "a negative integer is :non_numeric" do
      assert Fix.fix(-1) == {:error, :non_numeric}
    end

    test "a list with an out-of-range element is :non_numeric" do
      assert Fix.fix([1, 2, 10]) == {:error, :non_numeric}
    end
  end

  describe "fix/2 with an explicit target length" do
    test "pads to a numeric target length" do
      assert Fix.fix("495205944325", 13) == {:ok, "0495205944325"}
    end

    test "accepts a named atom target" do
      assert Fix.fix("495205944325", :gtin13) == {:ok, "0495205944325"}
    end

    test "pads all-zeros to each supported target" do
      assert Fix.fix("0", 8) == {:ok, "00000000"}
      assert Fix.fix("0", 12) == {:ok, "000000000000"}
      assert Fix.fix("0", 13) == {:ok, "0000000000000"}
      assert Fix.fix("0", 14) == {:ok, "00000000000000"}
    end

    test "an input longer than the target is :too_long" do
      assert Fix.fix("0000000000000", 12) == {:error, :too_long}
    end

    test "a right-length input with a bad check digit is :check_digit_incorrect" do
      assert Fix.fix("8845791354262", 13) == {:error, :check_digit_incorrect}
    end

    test "raises for an unsupported target" do
      assert_raise ArgumentError, fn -> Fix.fix("0", 10) end
      assert_raise ArgumentError, fn -> Fix.fix("0", :gtin10) end
    end
  end

  describe "each wrong check digit fails (borrowed from the Rust suite)" do
    # For the all-zeros GTIN-13 body the correct check digit is 0, so every
    # other trailing digit must fail to validate.
    for wrong <- 1..9 do
      test "GTIN-13 all-zeros with trailing #{wrong} is :check_digit_incorrect" do
        code = "000000000000#{unquote(wrong)}"
        assert Fix.fix(code, 13) == {:error, :check_digit_incorrect}
      end
    end
  end

  describe "fix!/1 and fix!/2 raising variants" do
    test "return the corrected string on success" do
      assert Fix.fix!("87248795257") == "087248795257"
      assert Fix.fix!("495205944325", 13) == "0495205944325"
    end

    test "raise ArgumentError with the reason on failure" do
      assert_raise ArgumentError, "check_digit_incorrect", fn -> Fix.fix!("123456789013") end
      assert_raise ArgumentError, "too_long", fn -> Fix.fix!("0000000000000", 12) end
      assert_raise ArgumentError, "non_numeric", fn -> Fix.fix!("a") end
    end
  end

  describe "public facade parity" do
    test "ExGtin.fix/1 and ExGtin.fix/2 delegate to ExGtin.Fix" do
      assert ExGtin.fix("87248795257") == {:ok, "087248795257"}
      assert ExGtin.fix("495205944325", 13) == {:ok, "0495205944325"}
      assert ExGtin.fix!("87248795257") == "087248795257"
      assert ExGtin.fix!("495205944325", 13) == "0495205944325"
    end
  end

  describe "properties" do
    property "fix/1 never raises on arbitrary strings and always returns a tuple" do
      check all(s <- string(:printable, max_length: 20)) do
        assert match?({:ok, _}, Fix.fix(s)) or match?({:error, _}, Fix.fix(s))
      end
    end

    property "a corrected code is idempotent and validates" do
      # Random valid-length GTIN bodies, generated with a correct check digit,
      # optionally stripped of a leading zero: fix must recover a valid code,
      # and re-fixing it is a no-op.
      check all(body <- list_of(integer(0..9), length: 12)) do
        code = Enum.join(ExGtin.CheckDigit.append(body))
        {:ok, fixed} = Fix.fix(code, 13)

        assert {:ok, "GTIN-13"} = ExGtin.validate(fixed)
        assert Fix.fix(fixed, 13) == {:ok, fixed}
      end
    end

    property "dropping a genuine leading zero is recovered by fix/2" do
      # Build a valid 13-digit code whose first digit is 0, drop exactly that
      # one leading zero to get a 12-char string, and confirm fix/2 re-pads it
      # back to the identical original code.
      check all(body <- list_of(integer(0..9), length: 11)) do
        code = Enum.join(ExGtin.CheckDigit.append([0 | body]))
        without_leading_zero = String.slice(code, 1..-1//1)

        assert Fix.fix(without_leading_zero, 13) == {:ok, code}
      end
    end
  end
end
