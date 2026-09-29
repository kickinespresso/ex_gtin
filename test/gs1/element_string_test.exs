defmodule ExGtin.GS1.ElementStringTest do
  @moduledoc """
  Tests for the GS1 element-string parser (`ExGtin.GS1.ElementString`).

  Parenthesized form: a parenthesized element string of supported AIs parses to
  `{:ok, map}` mapping each AI code to its value; a fixed-length AI value with
  the wrong length errors identifying the AI; an AI code not in the dictionary
  errors identifying the unknown AI; and a malformed payload (unbalanced
  parentheses) errors with position information.

  Raw FNC1 form: fixed-length AIs concatenated without a separator are segmented
  by dictionary length; a variable-length AI followed by more data terminates at
  the FNC1/GS separator; the raw and parenthesized forms of the same logical
  payload produce equal maps; and a trailing variable-length AI with no
  separator consumes the remainder.

  Embedded identifiers and dates: a valid embedded GTIN (AI 01) parses
  successfully and an embedded GTIN whose check digit fails — or that is
  non-numeric — errors identifying the invalid GTIN; date AIs (11/13/15/17)
  surface as their raw `YYMMDD` string by default; and date interpretation is
  opt-in via `dates: :parsed`, mapping the value into an Elixir `Date` while
  leaving the raw string as the default.

  The module doctests (on `parse_parenthesized/1` and `parse_raw/1`) are included
  via `doctest`.
  """
  use ExUnit.Case

  doctest ExGtin.GS1.ElementString

  alias ExGtin.GS1.ElementString

  describe "multi-AI parenthesized payloads parse correctly" do
    test "a GTIN + expiration date + batch payload parses to the expected map" do
      assert {:ok, %{"01" => "06291041500213", "17" => "261231", "10" => "ABC123"}} =
               ElementString.parse_parenthesized("(01)06291041500213(17)261231(10)ABC123")
    end

    test "a single fixed-length AI parses" do
      assert {:ok, %{"01" => "06291041500213"}} =
               ElementString.parse_parenthesized("(01)06291041500213")
    end

    test "a single variable-length AI parses and consumes the remainder" do
      assert {:ok, %{"10" => "LOT-42"}} =
               ElementString.parse_parenthesized("(10)LOT-42")
    end

    test "a weight AI (3xx, fixed 6) parses alongside a GTIN" do
      assert {:ok, %{"01" => "06291041500213", "3103" => "000123"}} =
               ElementString.parse_parenthesized("(01)06291041500213(3103)000123")
    end

    test "an empty payload parses to an empty map" do
      assert {:ok, %{}} = ElementString.parse_parenthesized("")
    end
  end

  describe "unknown AI errors with code + position" do
    test "an unsupported leading AI reports the code and position 0" do
      assert {:error, {:unknown_ai, "99", 0}} =
               ElementString.parse_parenthesized("(99)000000")
    end

    test "an unknown AI after a valid segment surfaces the unparsed remainder" do
      # Once a leading segment has parsed, an unknown trailing AI is not a hard
      # error: the interpreted prefix is returned and the uninterpretable tail is
      # reported as the unparsed remainder rather than dropped.
      assert {:ok, %{"01" => "06291041500213"}, "(99)000000"} =
               ElementString.parse_parenthesized("(01)06291041500213(99)000000")
    end
  end

  describe "wrong fixed-length value errors identifying the AI + position" do
    test "a too-short GTIN value reports the AI, expected/actual lengths, position" do
      assert {:error, {:invalid_length, "01", 14, 3, 0}} =
               ElementString.parse_parenthesized("(01)123")
    end

    test "a too-long GTIN value reports the AI, expected/actual lengths, position" do
      assert {:error, {:invalid_length, "01", 14, 15, 0}} =
               ElementString.parse_parenthesized("(01)062910415002130")
    end

    test "a wrong-length value in a later segment reports its position" do
      # First segment "(01)06291041500213" is 18 bytes.
      assert {:error, {:invalid_length, "17", 6, 3, 18}} =
               ElementString.parse_parenthesized("(01)06291041500213(17)261")
    end
  end

  describe "unbalanced parentheses errors with position" do
    test "a leading segment missing its closing paren reports position 0" do
      assert {:error, {:unbalanced_parentheses, 0}} =
               ElementString.parse_parenthesized("(01")
    end

    test "a payload not starting with an opening paren reports position 0" do
      assert {:error, {:unbalanced_parentheses, 0}} =
               ElementString.parse_parenthesized("01)06291041500213")
    end

    test "a trailing segment missing its closing paren reports its byte position" do
      # First segment "(01)06291041500213" is 18 bytes; the malformed "(10"
      # starts at 18.
      assert {:error, {:unbalanced_parentheses, 18}} =
               ElementString.parse_parenthesized("(01)06291041500213(10")
    end
  end

  # The FNC1/GS separator that terminates a variable-length AI in the raw form.
  @gs <<29>>

  describe "fixed-length AIs segmented without a separator" do
    test "a single fixed-length AI is segmented by its dictionary length" do
      assert {:ok, %{"01" => "06291041500213"}} =
               ElementString.parse_raw("0106291041500213")
    end

    test "multiple fixed AIs concatenated segment using dictionary lengths" do
      # AI 01 (fixed 14) + AI 17 (fixed 6) run together with no separator.
      assert {:ok, %{"01" => "06291041500213", "17" => "261231"}} =
               ElementString.parse_raw("010629104150021317261231")
    end

    test "a fixed weight AI (3xx, fixed 6) is segmented after a GTIN" do
      assert {:ok, %{"01" => "06291041500213", "3103" => "000123"}} =
               ElementString.parse_raw("01062910415002133103000123")
    end
  end

  describe "variable-length AIs terminated by FNC1/GS" do
    test "a variable AI followed by more data terminates at the separator" do
      assert {:ok, %{"10" => "ABC123", "17" => "261231"}} =
               ElementString.parse_raw("10ABC123" <> @gs <> "17261231")
    end

    test "a fixed AI, then a variable AI terminated by the separator, then a fixed AI" do
      assert {:ok, %{"01" => "06291041500213", "10" => "LOT-42", "17" => "261231"}} =
               ElementString.parse_raw("010629104150021310LOT-42" <> @gs <> "17261231")
    end

    test "two variable AIs each terminated by their own separator" do
      assert {:ok, %{"10" => "ABC123", "21" => "XYZ789"}} =
               ElementString.parse_raw("10ABC123" <> @gs <> "21XYZ789" <> @gs)
    end
  end

  describe "trailing variable AI consumes the remainder" do
    test "a trailing variable AI with no separator consumes the rest of the payload" do
      assert {:ok, %{"01" => "06291041500213", "10" => "ABC123"}} =
               ElementString.parse_raw("010629104150021310ABC123")
    end

    test "a lone trailing variable AI consumes its whole value" do
      assert {:ok, %{"21" => "XYZ789"}} =
               ElementString.parse_raw("21XYZ789")
    end
  end

  describe "raw and parenthesized forms of the same payload produce equal maps" do
    test "a fixed-only payload parses equally in both forms" do
      # No variable AIs, so the raw form needs no separator at all.
      raw = "010629104150021317261231"
      parenthesized = "(01)06291041500213(17)261231"

      assert {:ok, map} = ElementString.parse_raw(raw)
      assert {:ok, ^map} = ElementString.parse_parenthesized(parenthesized)
      assert map == %{"01" => "06291041500213", "17" => "261231"}
    end

    test "a payload with a mid-string variable AI parses equally in both forms" do
      # The variable AI 10 sits mid-payload, so the raw form needs the FNC1/GS
      # separator to terminate it; the parenthesized form is self-delimiting and
      # needs none. Both must yield the same map.
      raw = "010629104150021310ABC123" <> @gs <> "17261231"
      parenthesized = "(01)06291041500213(10)ABC123(17)261231"

      assert {:ok, map} = ElementString.parse_raw(raw)
      assert {:ok, ^map} = ElementString.parse_parenthesized(parenthesized)
      assert map == %{"01" => "06291041500213", "10" => "ABC123", "17" => "261231"}
    end

    test "a payload ending in a trailing variable AI parses equally in both forms" do
      # The trailing variable AI 21 consumes the remainder in the raw form, so no
      # separator is required at the end.
      raw = "010629104150021321XYZ789"
      parenthesized = "(01)06291041500213(21)XYZ789"

      assert {:ok, map} = ElementString.parse_raw(raw)
      assert {:ok, ^map} = ElementString.parse_parenthesized(parenthesized)
      assert map == %{"01" => "06291041500213", "21" => "XYZ789"}
    end
  end

  describe "embedded GTIN (AI 01) is validated via the check-digit engine" do
    test "a valid embedded GTIN parses successfully in the parenthesized form" do
      assert {:ok, %{"01" => "06291041500213"}} =
               ElementString.parse_parenthesized("(01)06291041500213")
    end

    test "a valid embedded GTIN parses successfully in the raw form" do
      assert {:ok, %{"01" => "06291041500213"}} =
               ElementString.parse_raw("0106291041500213")
    end

    test "a valid embedded GTIN alongside other AIs parses successfully" do
      assert {:ok, %{"01" => "06291041500213", "10" => "ABC123"}} =
               ElementString.parse_parenthesized("(01)06291041500213(10)ABC123")
    end
  end

  describe "an invalid embedded GTIN errors identifying the GTIN" do
    test "a GTIN with a bad check digit errors (parenthesized form)" do
      # "06291041500213" is valid; flipping the last digit to 4 breaks the
      # mod-10 check digit.
      assert {:error, {:invalid_gtin, "06291041500214"}} =
               ElementString.parse_parenthesized("(01)06291041500214")
    end

    test "a GTIN with a bad check digit errors (raw form)" do
      assert {:error, {:invalid_gtin, "06291041500214"}} =
               ElementString.parse_raw("0106291041500214")
    end

    test "a non-numeric GTIN value errors identifying the GTIN" do
      # The final character is a letter, so the value is not a valid GTIN.
      assert {:error, {:invalid_gtin, "0629104150021X"}} =
               ElementString.parse_parenthesized("(01)0629104150021X")
    end
  end

  describe "date AIs surface as raw YYMMDD by default" do
    test "an expiration date (AI 17) is the raw YYMMDD string, not a Date" do
      assert {:ok, %{"17" => "261231"}} = ElementString.parse_raw("17261231")
    end

    test "every date AI (11/13/15/17) surfaces as its raw string by default" do
      assert {:ok, %{"11" => "260101"}} = ElementString.parse_raw("11260101")
      assert {:ok, %{"13" => "260202"}} = ElementString.parse_raw("13260202")
      assert {:ok, %{"15" => "260303"}} = ElementString.parse_raw("15260303")
      assert {:ok, %{"17" => "261231"}} = ElementString.parse_raw("17261231")
    end

    test "the parenthesized form also leaves date AIs raw by default" do
      assert {:ok, %{"17" => "261231"}} =
               ElementString.parse_parenthesized("(17)261231")
    end
  end

  describe "opt-in date interpretation via dates: :parsed" do
    test "dates: :parsed interprets an expiration date into a Date (raw form)" do
      # Current-year context is 2026, and the GS1 year window
      # [current_year - 49, current_year + 50] maps "26" -> 2026.
      assert {:ok, %{"17" => ~D[2026-12-31]}} =
               ElementString.parse_raw("17261231", dates: :parsed)
    end

    test "dates: :parsed interprets a date in the parenthesized form" do
      assert {:ok, %{"17" => ~D[2026-12-31]}} =
               ElementString.parse_parenthesized("(17)261231", dates: :parsed)
    end

    test "a \"00\" day is interpreted as the last day of the month under :parsed" do
      # AI 17 value 261200 -> December 2026 with an unspecified day, which GS1
      # reads as "end of month": 2026-12-31.
      assert {:ok, %{"17" => ~D[2026-12-31]}} =
               ElementString.parse_raw("17261200", dates: :parsed)
    end

    test "an invalid date under :parsed errors identifying the AI and value" do
      # Month 13 is not a valid calendar month.
      assert {:error, {:invalid_date, "17", "261301"}} =
               ElementString.parse_raw("17261301", dates: :parsed)
    end

    test "the raw string remains the default when :dates is not requested" do
      assert {:ok, %{"17" => "261231"}} = ElementString.parse_raw("17261231")
    end
  end
end
