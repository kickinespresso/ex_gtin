defmodule ExGtin.Keys do
  @moduledoc """
  Validation and generation for fixed-length GS1 identifier keys beyond the
  GTIN family, built on the shared mod-10 engine.

  GS1 defines several identifier keys — SSCC (Serial Shipping Container Code),
  GSIN, GLN, and others — that all use the same mod-10 check-digit math as the
  GTIN, differing only in length and formatting. This module hosts the keys
  that are *not* GTINs so that GTIN length detection
  (`ExGtin.Validation.check_code_length/1`) stays GTIN-scoped.

  Keeping key detection explicit (a caller asks for an SSCC, not "whatever this
  length is") avoids length collisions: an 18-digit SSCC is never misread as an
  over-length GTIN, and a 14-digit GTIN is never misread as an SSCC.

  Each key shares the `ExGtin.CheckDigit` engine (mod-10 over digit lists).
  Inputs may be a `String`, an integer, or a digit list, matching the rest of
  the `ExGtin` API. Non-bang functions return `{:ok, _} | {:error, binary}`.

  Beyond the SSCC/GSIN wrappers, a `@key_lengths` table drives the generic
  `validate_key/2` and `generate_key/2`, which handle every fixed-length key
  (see `t:gs1_key/0`) with the same length + mod-10 logic. The SSCC and GSIN
  functions are thin wrappers over that path and keep returning their
  string labels (`"SSCC"` / `"GSIN"`).

  ## Variable-component keys (GRAI, GIAI, GDTI)

  Three GS1 keys are *not* pure fixed-length + mod-10 checks because they carry
  a variable serial/reference component. These are validated by dedicated
  per-key format functions (wired into `validate_key/2`), not by the length
  table — they are explicitly **not** shipped as "length only":

    * `:grai` (GRAI, AI 8003) — a 14-digit numeric core (a leading `0`, a
      GS1 Company Prefix + asset type, and a mod-10 check digit over the first
      13 numeric digits) optionally followed by a serial of up to 16 characters
      from GS1 Character Set 82. The check digit covers the numeric core only.
    * `:giai` (GIAI, AI 8004) — a numeric GS1 Company Prefix followed by an
      alphanumeric individual asset reference, up to 30 Character-Set-82
      characters in total, with **no** check digit.
    * `:gdti` (GDTI, AI 253) — a 13-digit numeric core (12 digits + a mod-10
      check digit, same structure as a GTIN-13/GLN) optionally followed by a
      serial of up to 17 numeric digits. `validate_key(_, :gdti)` accepts both
      the base 13-digit form (via the fixed-length table) and the serialized
      form (13-digit core + 1..17 numeric serial).

  Because a serial component is free-form, `generate_key/2` remains undefined
  (returns `{:error, "Unsupported key"}`) for `:grai`, `:giai`, and `:gdti`:
  there is no single canonical code to generate from a body when an arbitrary
  serial may follow. Use `validate_key/2` to validate these keys.

  > #### GS1 Character Set 82 {: .info}
  >
  > GRAI serials and the whole GIAI are constrained to GS1 Character Set 82
  > (a subset of ISO/IEC 646): digits `0-9`, upper- and lower-case ASCII
  > letters, and the 20 special characters `! " % & ' ( ) * + , - . / : ; < =
  > > ? _`. Space is excluded.

  > #### Integer leading-zero caveat {: .warning}
  >
  > An SSCC often begins with a leading zero (the extension digit is commonly
  > `0`), which an integer input silently drops. Supply such codes as a
  > `String` or digit list to preserve length.
  """
  @moduledoc since: "1.4.0"

  @typedoc """
  A GS1 identifier key handled by the generic `validate_key/2` path.

  The *fixed-length* keys are fully described by a total length and a trailing
  mod-10 check digit and are driven by `@key_lengths`:

    * `:gln`  — Global Location Number (13)
    * `:sscc` — Serial Shipping Container Code (18)
    * `:gsin` — Global Shipment Identification Number (17)
    * `:gsrn` — Global Service Relation Number (18)
    * `:gcn`  — Global Coupon Number (13)
    * `:gdti` — Global Document Type Identifier, base form (13)

  The *variable-component* keys carry a free-form component and are validated by
  dedicated per-key format functions (see the module doc), not by length alone:

    * `:grai` — Global Returnable Asset Identifier (AI 8003)
    * `:giai` — Global Individual Asset Identifier (AI 8004)
    * `:gdti` — Global Document Type Identifier with a serial (AI 253); the
      `:gdti` atom covers both the base 13-digit form and the serialized form.

  `generate_key/2` supports only the fixed-length keys; the variable-component
  keys return `{:error, "Unsupported key"}` because a serial component has no
  single canonical value to generate.
  """
  @type gs1_key :: :gln | :sscc | :gsin | :gsrn | :gcn | :gdti | :grai | :giai

  # Total length (including the trailing check digit) of each fixed-length GS1
  # key. This single table drives the generic validate_key/2 and generate_key/2,
  # and the SSCC/GSIN wrappers read their lengths from it so there is one source
  # of truth. Only keys that are pure length + mod-10 belong here; variable-
  # component keys (GRAI, GIAI, serialized GDTI) need format rules and are
  # deliberately excluded.
  @key_lengths %{
    gln: 13,
    sscc: 18,
    gsin: 17,
    gsrn: 18,
    gcn: 13,
    gdti: 13
  }

  @doc """
  Validates an 18-digit SSCC.

  Returns `{:ok, "SSCC"}` when the input is exactly 18 digits and its final
  digit is the correct mod-10 check digit for the preceding 17-digit body.
  Returns `{:error, "Invalid Code"}` when the length is 18 but the check digit
  does not match, and an `{:error, _}` tuple for any wrong-length or non-digit
  input.

  ## Examples

      iex> ExGtin.Keys.validate_sscc("106141412345678908")
      {:ok, "SSCC"}

      iex> ExGtin.Keys.validate_sscc("106141412345678909")
      {:error, "Invalid Code"}

      iex> ExGtin.Keys.validate_sscc("12345")
      {:error, "Invalid Code"}

  """
  @doc since: "1.4.0"
  @spec validate_sscc(String.t() | integer | list(0..9)) ::
          {:ok, String.t()} | {:error, String.t()}
  def validate_sscc(sscc) do
    with {:ok, :sscc} <- validate_key(sscc, :sscc) do
      {:ok, "SSCC"}
    end
  end

  @doc """
  Generates a complete 18-digit SSCC from a 17-digit body.

  Takes the 17-digit body (the SSCC without its check digit), computes the
  mod-10 check digit, and returns `{:ok, sscc}` as an 18-digit string. Returns
  an `{:error, _}` tuple when the body is not exactly 17 digits or contains
  non-digit content.

  ## Examples

      iex> ExGtin.Keys.generate_sscc("10614141234567890")
      {:ok, "106141412345678908"}

  """
  @doc since: "1.4.0"
  @spec generate_sscc(String.t() | integer | list(0..9)) ::
          {:ok, String.t()} | {:error, String.t()}
  def generate_sscc(body) do
    generate_key(body, :sscc)
  end

  @doc """
  Validates a 17-digit GSIN.

  Returns `{:ok, "GSIN"}` when the input is exactly 17 digits and its final
  digit is the correct mod-10 check digit for the preceding 16-digit body.
  Returns `{:error, "Invalid Code"}` when the length is 17 but the check digit
  does not match, and an `{:error, _}` tuple for any wrong-length or non-digit
  input.

  ## Examples

      iex> ExGtin.Keys.validate_gsin("10614141234567894")
      {:ok, "GSIN"}

      iex> ExGtin.Keys.validate_gsin("10614141234567895")
      {:error, "Invalid Code"}

      iex> ExGtin.Keys.validate_gsin("12345")
      {:error, "Invalid Code"}

  """
  @doc since: "1.4.0"
  @spec validate_gsin(String.t() | integer | list(0..9)) ::
          {:ok, String.t()} | {:error, String.t()}
  def validate_gsin(gsin) do
    with {:ok, :gsin} <- validate_key(gsin, :gsin) do
      {:ok, "GSIN"}
    end
  end

  @doc """
  Generates a complete 17-digit GSIN from a 16-digit body.

  Takes the 16-digit body (the GSIN without its check digit), computes the
  mod-10 check digit, and returns `{:ok, gsin}` as a 17-digit string. Returns
  an `{:error, _}` tuple when the body is not exactly 16 digits or contains
  non-digit content.

  ## Examples

      iex> ExGtin.Keys.generate_gsin("1061414123456789")
      {:ok, "10614141234567894"}

  """
  @doc since: "1.4.0"
  @spec generate_gsin(String.t() | integer | list(0..9)) ::
          {:ok, String.t()} | {:error, String.t()}
  def generate_gsin(body) do
    generate_key(body, :gsin)
  end

  @doc """
  Validates a fixed-length GS1 key by length and mod-10 check digit.

  `code` may be a `String`, an integer, or a digit list. `key` names which
  key to check against (see `t:gs1_key/0`) — the caller states the key
  explicitly so that same-length keys never collide (an 18-digit value could be
  either an `:sscc` or a `:gsrn`, and only the caller knows which).

  For the fixed-length keys, returns `{:ok, key}` (the key atom) when the input
  has exactly the expected length for `key` and a valid mod-10 check digit.
  Returns `{:error, "Invalid Code"}` when the length matches but the check digit
  does not, and an `{:error, _}` tuple for any wrong-length or non-digit input.

  For the variable-component keys the format rules are validated (see below),
  and `{:ok, key}` is returned on success.

  ## Variable-component keys

  These are **not** validated by length alone; each has its own format rules:

    * `:grai` — 14-digit numeric core (`"0"` + 13 digits, last is a mod-10 check
      over the first 13) plus an optional serial of up to 16 GS1
      Character-Set-82 characters. Errors: `"Invalid GRAI"` for a malformed
      structure (wrong core length, bad serial, non-CSET-82), `"Invalid Code"`
      when the core check digit is wrong.
    * `:giai` — a numeric GS1 Company Prefix followed by an alphanumeric asset
      reference, 1..30 Character-Set-82 characters total, no check digit.
      Error: `"Invalid GIAI"`.
    * `:gdti` — a 13-digit numeric core (12 + mod-10 check) with an optional
      serial of up to 17 numeric digits. The base 13-digit form is accepted via
      the fixed-length path; a serialized form adds the numeric serial. Errors:
      `"Invalid GDTI"` for a malformed structure, `"Invalid Code"` when the
      core check digit is wrong.

  Any key outside `t:gs1_key/0` returns `{:error, "Unsupported key"}`.

  ## Examples

      iex> ExGtin.Keys.validate_key("4012345000009", :gln)
      {:ok, :gln}

      iex> ExGtin.Keys.validate_key("401234500000000012", :gsrn)
      {:ok, :gsrn}

      iex> ExGtin.Keys.validate_key("4012345000008", :gln)
      {:error, "Invalid Code"}

      iex> ExGtin.Keys.validate_key("12345", :gln)
      {:error, "Invalid Code"}

  A GRAI numeric core (a leading `0` plus a GTIN-13-style body with a valid
  check digit), with and without a serial:

      iex> ExGtin.Keys.validate_key("00614141543212", :grai)
      {:ok, :grai}

      iex> ExGtin.Keys.validate_key("00614141543212Ab7/", :grai)
      {:ok, :grai}

      iex> ExGtin.Keys.validate_key("00614141543213", :grai)
      {:error, "Invalid Code"}

  A GIAI is a numeric-prefixed alphanumeric string with no check digit:

      iex> ExGtin.Keys.validate_key("4000001111", :giai)
      {:ok, :giai}

      iex> ExGtin.Keys.validate_key("40000011112ABCxyz", :giai)
      {:ok, :giai}

      iex> ExGtin.Keys.validate_key("ABC123", :giai)
      {:error, "Invalid GIAI"}

  A GDTI validates the 13-digit core and an optional numeric serial:

      iex> ExGtin.Keys.validate_key("4012345000009", :gdti)
      {:ok, :gdti}

      iex> ExGtin.Keys.validate_key("4012345000009123456", :gdti)
      {:ok, :gdti}

      iex> ExGtin.Keys.validate_key("4012345000008", :gdti)
      {:error, "Invalid Code"}

  """
  @doc since: "1.4.0"
  @spec validate_key(String.t() | integer | list(0..9), gs1_key) ::
          {:ok, gs1_key} | {:error, String.t()}
  def validate_key(code, :grai), do: validate_grai(code)
  def validate_key(code, :giai), do: validate_giai(code)
  def validate_key(code, :gdti), do: validate_gdti(code)

  def validate_key(code, key) do
    with {:ok, length} <- key_length(key),
         {:ok, digits} <- to_digits(code),
         {:ok, digits} <- require_length(digits, length) do
      if ExGtin.CheckDigit.valid?(digits) do
        {:ok, key}
      else
        {:error, "Invalid Code"}
      end
    end
  end

  @doc """
  Generates a complete fixed-length GS1 key from its body.

  Takes `body` — the key without its trailing check digit, one digit shorter
  than the full key — as a `String`, integer, or digit list, computes the mod-10
  check digit, and returns `{:ok, code}` with the check digit appended. `key`
  names which fixed-length key to build.

  Only the fixed-length keys can be generated (GLN, SSCC, GSIN, GSRN, GCN, and
  the base 13-digit GDTI). Returns an `{:error, _}` tuple when the body is not
  exactly the expected length for `key` or contains non-digit content.

  The variable-component keys `:grai` and `:giai` return
  `{:error, "Unsupported key"}`: a GRAI/GIAI carries a free-form serial or asset
  reference, so there is no single canonical code to generate from a body.
  A serialized GDTI likewise cannot be generated (the serial is arbitrary);
  `generate_key(_, :gdti)` only ever produces the base 13-digit form. Validate
  variable-component keys with `validate_key/2` instead.

  ## Examples

      iex> ExGtin.Keys.generate_key("401234500000", :gln)
      {:ok, "4012345000009"}

      iex> ExGtin.Keys.generate_key("40123450000000001", :gsrn)
      {:ok, "401234500000000012"}

      iex> ExGtin.Keys.generate_key("401234500000", :gdti)
      {:ok, "4012345000009"}

      iex> ExGtin.Keys.generate_key("12345", :gln)
      {:error, "Invalid Code"}

      iex> ExGtin.Keys.generate_key("00000000", :grai)
      {:error, "Unsupported key"}

      iex> ExGtin.Keys.generate_key("00000000", :giai)
      {:error, "Unsupported key"}

  """
  @doc since: "1.4.0"
  @spec generate_key(String.t() | integer | list(0..9), gs1_key) ::
          {:ok, String.t()} | {:error, String.t()}
  def generate_key(body, key) do
    with {:ok, length} <- key_length(key),
         {:ok, digits} <- to_digits(body),
         {:ok, digits} <- require_length(digits, length - 1) do
      {:ok, digits |> ExGtin.CheckDigit.append() |> Enum.join()}
    end
  end

  # ---------------------------------------------------------------------------
  # Variable-component key validators
  #
  # These keys carry a variable serial/reference component and so are validated
  # by format rules layered on top of the check-digit engine, NOT by length
  # alone. Structural facts (GS1 General Specifications) and sources are
  # documented at each function. Inputs are normalised to a String first so the
  # alphanumeric serial/reference components are preserved (a digit-list or
  # integer input cannot represent letters; such inputs are simply treated as
  # their string form via to_string/1 where meaningful).
  # ---------------------------------------------------------------------------

  # GS1 Character Set 82 (a subset of ISO/IEC 646): digits, upper/lower-case
  # ASCII letters, and 20 special characters, excluding space. Source:
  # https://xchange.gs1.org/sites/glossary/en-gb/Pages/Character%20set%2082.aspx
  # and the enumerated table at
  # https://onbarcode.com/kb/barcode-faq/gs1-iso-646-encode/
  @cset82_specials String.to_charlist("!\"%&'()*+,-./:;<=>?_")

  @spec cset82?(String.t()) :: boolean
  defp cset82?(string) do
    string
    |> String.to_charlist()
    |> Enum.all?(fn c ->
      c in ?0..?9 or c in ?A..?Z or c in ?a..?z or c in @cset82_specials
    end)
  end

  # True when every character of the string is an ASCII digit (and non-empty).
  @spec all_digits?(String.t()) :: boolean
  defp all_digits?(""), do: false

  defp all_digits?(string) do
    string |> String.to_charlist() |> Enum.all?(&(&1 in ?0..?9))
  end

  # Validates the mod-10 check digit of a numeric string whose final digit is
  # the check digit, delegating to the shared engine.
  @spec numeric_core_valid?(String.t()) :: boolean
  defp numeric_core_valid?(numeric) do
    case to_digits(numeric) do
      {:ok, digits} -> ExGtin.CheckDigit.valid?(digits)
      _ -> false
    end
  end

  # GRAI, AI (8003). Structure per GS1 General Specifications:
  #   - a 14-digit numeric core: a leading "0", a GS1 Company Prefix + asset
  #     type reference (12 digits), and a mod-10 check digit; the check digit is
  #     computed over the first 13 numeric digits (same math as GTIN-14).
  #     Sources: https://www.gs1jp.org/standard/identify/grai/ (14-digit core:
  #     leading zero + GS1 company code + asset type + check digit, "check digit
  #     computed as for GTIN-14"); https://gs1it.org/assistenza/standard-specifiche/grai/
  #   - an OPTIONAL serial component of up to 16 Character-Set-82 characters.
  #     Source: https://gs1it.org/assistenza/standard-specifiche/grai/
  #     ("optional serial part, variable length, max 16 alphanumeric characters").
  # The check digit applies to the numeric core only, never the serial.
  @spec validate_grai(String.t() | integer | list(0..9)) ::
          {:ok, :grai} | {:error, String.t()}
  defp validate_grai(code) do
    string = normalize_input(code)

    case String.split_at(string, 14) do
      {core, serial} ->
        cond do
          # First 14 chars must all be digits and start with the leading "0".
          not all_digits?(core) or not String.starts_with?(core, "0") ->
            {:error, "Invalid GRAI"}

          # Serial (if present) is 1..16 CSET 82 characters.
          serial != "" and (String.length(serial) > 16 or not cset82?(serial)) ->
            {:error, "Invalid GRAI"}

          # Mod-10 check digit over the 14-digit numeric core.
          not numeric_core_valid?(core) ->
            {:error, "Invalid Code"}

          true ->
            {:ok, :grai}
        end
    end
  end

  # GIAI, AI (8004). Structure per GS1 General Specifications:
  #   - a numeric GS1 Company Prefix followed by an alphanumeric Individual
  #     Asset Reference, up to 30 Character-Set-82 characters in total, with NO
  #     check digit. Sources:
  #     https://www.gs1au.org/standards/id-keys/global-individual-asset-identifier-giai
  #     ("GS1 Company Prefix ... and an individual asset reference. The
  #     individual asset reference is alphanumeric.");
  #     https://www.oreilly.com/library/view/rfid-essentials/0596009445/chapter-148.html
  #     ("Note that there is no check digit.").
  # Validation is therefore a length + character-set + leading-numeric-prefix
  # check: 1..30 CSET-82 characters that begin with at least one digit (the
  # numeric company prefix).
  @spec validate_giai(String.t() | integer | list(0..9)) ::
          {:ok, :giai} | {:error, String.t()}
  defp validate_giai(code) do
    string = normalize_input(code)
    len = String.length(string)

    cond do
      len < 1 or len > 30 -> {:error, "Invalid GIAI"}
      not cset82?(string) -> {:error, "Invalid GIAI"}
      # Must start with a numeric GS1 Company Prefix.
      not starts_with_digit?(string) -> {:error, "Invalid GIAI"}
      true -> {:ok, :giai}
    end
  end

  # GDTI, AI (253). Structure per GS1 General Specifications:
  #   - a 13-digit numeric core: 12 digits (GS1 Company Prefix + document type)
  #     plus a mod-10 check digit, identical in structure to a GTIN-13/GLN.
  #   - an OPTIONAL serial component of up to 17 numeric digits. Sources:
  #     https://gs1.org/standards/barcodes/application-identifiers (AI 253 GDTI);
  #     https://gs1it.org/assistenza/standard-specifiche/gdti-global-document-type-identifier/
  #     ("optional serial part, variable length, max 17 characters").
  # The check digit applies to the 13-digit numeric core only. The base
  # 13-digit form (no serial) is accepted; a serialized form adds a 1..17 digit
  # numeric serial after the core.
  @spec validate_gdti(String.t() | integer | list(0..9)) ::
          {:ok, :gdti} | {:error, String.t()}
  defp validate_gdti(code) do
    string = normalize_input(code)

    case String.split_at(string, 13) do
      {core, serial} ->
        cond do
          not all_digits?(core) or String.length(core) != 13 ->
            {:error, "Invalid GDTI"}

          # Serial (if present) is 1..17 numeric digits.
          serial != "" and (String.length(serial) > 17 or not all_digits?(serial)) ->
            {:error, "Invalid GDTI"}

          not numeric_core_valid?(core) ->
            {:error, "Invalid Code"}

          true ->
            {:ok, :gdti}
        end
    end
  end

  # Coerces String / integer / digit-list input to the String form used by the
  # variable-component validators, which must inspect individual characters
  # (including letters and the CSET 82 specials that a digit list cannot hold).
  @spec normalize_input(String.t() | integer | list(0..9)) :: String.t()
  defp normalize_input(code) when is_bitstring(code), do: code
  defp normalize_input(code) when is_integer(code), do: Integer.to_string(code)
  defp normalize_input(code) when is_list(code), do: Enum.join(code)
  defp normalize_input(code), do: to_string(code)

  @spec starts_with_digit?(String.t()) :: boolean
  defp starts_with_digit?(<<c, _rest::binary>>) when c in ?0..?9, do: true
  defp starts_with_digit?(_), do: false

  # Looks up the total length of a supported fixed-length key, rejecting any
  # key that is not in @key_lengths (unknown keys and variable-component keys
  # that need dedicated format rules).
  @spec key_length(atom) :: {:ok, pos_integer} | {:error, String.t()}
  defp key_length(key) do
    case Map.fetch(@key_lengths, key) do
      {:ok, length} -> {:ok, length}
      :error -> {:error, "Unsupported key"}
    end
  end

  # Coerces String / integer / digit-list input to a digit list, rejecting any
  # non-digit content uniformly. Mirrors ExGtin.Parse.to_digits/1.
  @spec to_digits(String.t() | integer | list(0..9)) ::
          {:ok, list(0..9)} | {:error, String.t()}
  defp to_digits(code) when is_bitstring(code) do
    code
    |> String.codepoints()
    |> Enum.reduce_while({:ok, []}, fn c, {:ok, acc} ->
      case Integer.parse(c) do
        {n, ""} -> {:cont, {:ok, acc ++ [n]}}
        _ -> {:halt, {:error, "Invalid Code"}}
      end
    end)
  end

  defp to_digits(code) when is_integer(code) and code >= 0,
    do: {:ok, Integer.digits(code)}

  defp to_digits(code) when is_list(code) do
    case Enum.all?(code, &(is_integer(&1) and &1 in 0..9)) do
      true -> {:ok, code}
      false -> {:error, "Invalid Code"}
    end
  end

  defp to_digits(_), do: {:error, "Invalid Code"}

  # Requires a digit list to be exactly the given length; errors uniformly
  # otherwise so wrong-length input never falls through to a checksum test.
  @spec require_length(list(0..9), pos_integer) :: {:ok, list(0..9)} | {:error, String.t()}
  defp require_length(digits, length) when length(digits) == length, do: {:ok, digits}
  defp require_length(_digits, _length), do: {:error, "Invalid Code"}
end
