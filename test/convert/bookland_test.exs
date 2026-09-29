defmodule ExGtin.Convert.BooklandTest do
  @moduledoc """
  Tests for Bookland ISBN-10 ⇄ ISBN-13 conversion and ISBN validation
  (`ExGtin.Convert.Bookland`) and their public wiring on `ExGtin`.

  A valid ISBN-10 converts to `978` followed by its first 9 digits and a
  recomputed mod-10 check digit; a `978`-prefixed ISBN-13 converts back to an
  ISBN-10 with a recomputed mod-11 check digit, which may be `X`; a
  `979`-prefixed ISBN-13 has no ISBN-10 equivalent and yields an `{:error, _}`
  tuple; an ISBN-10 whose check digit is `X` is handled in both directions —
  expanding an `X`-ending ISBN-10 and producing an `X` when reducing an ISBN-13;
  an ISBN-10 with an invalid mod-11 check and an ISBN-13 with an invalid mod-10
  check are both rejected; and validation reuses the mod-11 `valid_isbn10?/1`
  helper via length-dispatched `valid_isbn?/1`.

  Every ISBN-13 check digit and every ISBN-10 `X`/numeric check digit is computed
  against the real conversion engine (`isbn10_check_digit/1`,
  `isbn10_to_isbn13/1`) rather than hand-invented, so the assertions pin actual
  behavior end to end.
  """
  use ExUnit.Case

  doctest ExGtin.Convert.Bookland

  alias ExGtin.Convert.Bookland

  # {isbn10, isbn13} vectors confirmed against the engine. The last two carry an
  # `X` mod-11 check digit, exercising the X case in both directions.
  @roundtrip_vectors [
    {"0306406152", "9780306406157"},
    {"0000000000", "9780000000002"},
    {"0471958697", "9780471958697"},
    {"155860832X", "9781558608320"},
    {"123456789X", "9781234567897"}
  ]

  describe "ISBN-10 → ISBN-13 is 978 + first 9 digits + recomputed check" do
    for {isbn10, isbn13} <- @roundtrip_vectors do
      test "#{isbn10} expands to #{isbn13}" do
        assert Bookland.isbn10_to_isbn13(unquote(isbn10)) == {:ok, unquote(isbn13)}
      end

      test "#{isbn13} starts with 978 + the first 9 ISBN-10 digits" do
        assert {:ok, isbn13} = Bookland.isbn10_to_isbn13(unquote(isbn10))
        assert String.starts_with?(isbn13, "978" <> String.slice(unquote(isbn10), 0, 9))
      end

      test "#{isbn13} validates as GTIN-13 via ExGtin.validate/1" do
        assert {:ok, isbn13} = Bookland.isbn10_to_isbn13(unquote(isbn10))
        assert ExGtin.validate(isbn13) == {:ok, "GTIN-13"}
      end
    end
  end

  describe "978 round-trip: isbn13_to_isbn10(isbn10_to_isbn13(x)) == {:ok, x}" do
    for {isbn10, _isbn13} <- @roundtrip_vectors do
      test "#{isbn10} round-trips through ISBN-13 and back" do
        assert {:ok, isbn13} = Bookland.isbn10_to_isbn13(unquote(isbn10))
        assert Bookland.isbn13_to_isbn10(isbn13) == {:ok, unquote(isbn10)}
      end
    end
  end

  describe "978-prefixed ISBN-13 → ISBN-10 recomputes the mod-11 check" do
    for {isbn10, isbn13} <- @roundtrip_vectors do
      test "#{isbn13} reduces to #{isbn10}" do
        assert Bookland.isbn13_to_isbn10(unquote(isbn13)) == {:ok, unquote(isbn10)}
      end
    end
  end

  describe "979-prefixed ISBN-13 has no ISBN-10 equivalent" do
    test "a valid 979-prefixed ISBN-13 yields the no-equivalent error" do
      assert Bookland.isbn13_to_isbn10("9791234567896") ==
               {:error, "ISBN-13 with 979 prefix has no ISBN-10 equivalent"}
    end
  end

  describe "X check digit handled in both directions" do
    test "an X-ending ISBN-10 expands to a valid ISBN-13" do
      assert Bookland.isbn10_to_isbn13("155860832X") == {:ok, "9781558608320"}
      assert Bookland.isbn10_to_isbn13("123456789X") == {:ok, "9781234567897"}
    end

    test "an ISBN-13 whose ISBN-10 check is 10 produces a trailing X" do
      assert Bookland.isbn13_to_isbn10("9781558608320") == {:ok, "155860832X"}
      assert Bookland.isbn13_to_isbn10("9781234567897") == {:ok, "123456789X"}
    end

    test "isbn10_check_digit/1 returns \"X\" when the mod-11 check value is 10" do
      assert Bookland.isbn10_check_digit("155860832") == "X"
      assert Bookland.isbn10_check_digit("123456789") == "X"
    end

    test "an X-ending ISBN-10 validates" do
      assert Bookland.valid_isbn?("155860832X")
      assert Bookland.valid_isbn?("123456789X")
    end
  end

  describe "invalid mod-11 (ISBN-10) and mod-10 (ISBN-13) are rejected" do
    test "an ISBN-10 with a bad mod-11 check is not convertible" do
      # 1234567890 is 10 well-formed characters but fails the mod-11 check.
      assert Bookland.isbn10_to_isbn13("1234567890") == {:error, "Invalid ISBN-10"}
    end

    test "an ISBN-13 with a bad mod-10 check is not convertible" do
      # 9780306406158 shares the body of the valid 9780306406157 but ends in 8.
      assert Bookland.isbn13_to_isbn10("9780306406158") == {:error, "Invalid ISBN-13"}
    end

    test "valid_isbn?/1 rejects a bad mod-11 ISBN-10 and a bad mod-10 ISBN-13" do
      refute Bookland.valid_isbn?("1234567890")
      refute Bookland.valid_isbn?("9780306406158")
    end
  end

  describe "valid_isbn?/1 dispatches on length" do
    test "valid 10-character ISBN-10s are accepted" do
      for {isbn10, _isbn13} <- @roundtrip_vectors do
        assert Bookland.valid_isbn?(isbn10)
      end
    end

    test "valid 13-digit ISBN-13s are accepted" do
      for {_isbn10, isbn13} <- @roundtrip_vectors do
        assert Bookland.valid_isbn?(isbn13)
      end
    end

    test "a valid 979-prefixed ISBN-13 is still a valid ISBN even without an ISBN-10 form" do
      assert Bookland.valid_isbn?("9791234567896")
    end

    test "non-ISBN lengths are rejected" do
      refute Bookland.valid_isbn?("12345")
      refute Bookland.valid_isbn?("978030640615")
      refute Bookland.valid_isbn?("97803064061570")
    end
  end

  describe "input shapes agree (String, integer, digit list)" do
    test "String, integer, and digit-list ISBN-13s convert identically" do
      digits = "9780306406157" |> String.codepoints() |> Enum.map(&String.to_integer/1)

      assert Bookland.isbn13_to_isbn10("9780306406157") == {:ok, "0306406152"}
      assert Bookland.isbn13_to_isbn10(digits) == {:ok, "0306406152"}
      assert Bookland.isbn13_to_isbn10(9_780_306_406_157) == {:ok, "0306406152"}
    end
  end

  describe "public ExGtin wiring" do
    test "ExGtin.isbn10_to_isbn13/1 delegates to ExGtin.Convert.Bookland.isbn10_to_isbn13/1" do
      assert ExGtin.isbn10_to_isbn13("0306406152") ==
               Bookland.isbn10_to_isbn13("0306406152")

      assert ExGtin.isbn10_to_isbn13("0306406152") == {:ok, "9780306406157"}
    end

    test "ExGtin.isbn13_to_isbn10/1 delegates to ExGtin.Convert.Bookland.isbn13_to_isbn10/1" do
      assert ExGtin.isbn13_to_isbn10("9780306406157") ==
               Bookland.isbn13_to_isbn10("9780306406157")

      assert ExGtin.isbn13_to_isbn10("9780306406157") == {:ok, "0306406152"}
    end

    test "ExGtin.isbn13_to_isbn10/1 surfaces the 979 error through the public API" do
      assert ExGtin.isbn13_to_isbn10("9791234567896") ==
               {:error, "ISBN-13 with 979 prefix has no ISBN-10 equivalent"}
    end

    test "ExGtin.valid_isbn?/1 delegates to ExGtin.Convert.Bookland.valid_isbn?/1" do
      assert ExGtin.valid_isbn?("9780306406157") == Bookland.valid_isbn?("9780306406157")
      assert ExGtin.valid_isbn?("9780306406157")
      refute ExGtin.valid_isbn?("1234567890")
    end
  end
end
