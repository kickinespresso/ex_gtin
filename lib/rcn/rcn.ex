defmodule ExGtin.RCN do
  @moduledoc """
  Restricted-circulation number (RCN) recognition for GS1 codes.

  A restricted-circulation number is a GTIN whose leading digits fall in the
  GS1 restricted-circulation ranges. These codes are issued for in-store or
  in-company use (for example variable-measure retail items priced by weight)
  and are not globally unique, so callers generally want to tell an RCN apart
  from a normal GTIN before attempting to decode any embedded price or weight.

  ## Recognized prefixes

  Recognition is kept **consistent with the existing GS1 prefix table** in
  `ExGtin.Validation` (`lookup_gs1_prefix/1`), which already flags the
  restricted-circulation ranges on the leading three digits:

    * `020`–`029` — restricted circulation numbers within a geographic region
      (Member-Organisation defined); the two-digit `02` prefix.
    * `200`–`299` — GS1 restricted circulation numbers within a geographic
      region (MO defined); the two-digit `20`–`29` prefixes.

  A code is recognized as an RCN when its leading three digits fall in either
  range — equivalently, a GTIN-13 that begins with `02` or `2`. The
  restricted-circulation-within-a-company range (`040`–`049`) is intentionally
  out of scope here: this module recognizes the `02` and `20`–`29` prefixes
  called out for RCN parsing.

  This module implements prefix recognition (`recognize/1`, `rcn_prefix?/1`) and
  scheme-driven decoding of an embedded price/weight (`decode/2`), including
  validation of a scheme's optional internal price/weight check digit. The
  public `parse_rcn/2` entry point is layered on top of `decode/2` in later work.
  """
  @moduledoc since: "1.5.0"

  alias ExGtin.RCN.Schemes

  # Restricted-circulation leading-3-digit ranges, matching the entries already
  # present in `ExGtin.Validation`'s GS1 prefix table. Keeping the ranges here
  # rather than re-deriving them from two-digit prefixes ensures recognition
  # stays in lockstep with that table.
  @rcn_prefix_ranges [020..029, 200..299]

  @typedoc """
  Accepted code input: a digit string (`"2001234500005"`), a non-negative
  integer, or a list of single digits.
  """
  @type code :: String.t() | non_neg_integer | [0..9]

  @typedoc """
  A scheme argument for decoding: either a shipped scheme's named atom (resolved
  via `ExGtin.RCN.Schemes.fetch/1`) or an explicit `t:ExGtin.RCN.Schemes.rcn_scheme/0`
  scheme map.
  """
  @type scheme :: atom | Schemes.rcn_scheme()

  @typedoc """
  A decoded RCN: the extracted item reference plus the embedded price or weight.

  Both the item reference and the embedded value are returned as the **raw digit
  substrings** extracted from the code (leading zeros preserved, no
  implied-decimal scaling applied). Keeping them as strings avoids baking a
  scheme-specific decimal convention into the result; callers apply any scaling
  their market requires. The embedded map carries exactly one key, `:price` or
  `:weight`, matching the scheme's `embedded` tag.
  """
  @type rcn_parsed :: %{
          item: String.t(),
          embedded: %{price: String.t()} | %{weight: String.t()}
        }

  # A GTIN-13 is exactly 13 digits; scheme digit positions are 1-based into it.
  @gtin13_length 13

  @doc """
  Recognizes whether `code` is a restricted-circulation number.

  Returns `{:ok, code}` when the code's leading three digits fall in an RCN
  range (`020`–`029` or `200`–`299`), preserving the input for downstream
  scheme decoding. Returns `{:error, reason}` when the prefix is not an RCN
  range or the input is not a decodable digit sequence.

  Accepts a digit string, a non-negative integer, or a list of single digits.

  ## Examples

      iex> ExGtin.RCN.recognize("2001234500009")
      {:ok, "2001234500009"}

      iex> ExGtin.RCN.recognize("0201234500002")
      {:ok, "0201234500002"}

      iex> ExGtin.RCN.recognize("6291041500213")
      {:error, "Not a restricted-circulation number"}

  """
  @doc since: "1.5.0"
  @spec recognize(code) :: {:ok, code} | {:error, String.t()}
  def recognize(code) do
    case rcn_prefix?(code) do
      {:ok, true} -> {:ok, code}
      {:ok, false} -> {:error, "Not a restricted-circulation number"}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Decodes an RCN's item reference and embedded price/weight against a `scheme`.

  `scheme` may be a shipped scheme's named atom (resolved via
  `ExGtin.RCN.Schemes.fetch/1`) or an explicit `t:ExGtin.RCN.Schemes.rcn_scheme/0`
  scheme map, so callers can use a documented default or supply their own market
  layout.

  On success returns `{:ok, t:rcn_parsed/0}` — a map with the extracted `item`
  reference and an `embedded` map carrying the raw digit substring under
  `:price` or `:weight`, per the scheme's `embedded` tag. The item reference and
  embedded value are returned as raw digit strings (leading zeros preserved, no
  implied-decimal scaling applied); callers apply any scaling their market needs.

  The code is normalized to a 13-digit GTIN-13 and rejected with `{:error, _}`
  when it is the wrong length or is not a digit sequence. A basic prefix check
  rejects a code whose leading digit is not listed in the scheme's `prefix`.

  When the scheme declares an internal price/weight check digit
  (`check: {:price_check, position}`), the digit at that 1-based position is
  validated against a GS1 mod-10 check digit computed over the embedded
  price/weight field via `ExGtin.CheckDigit.mod10/1`; a mismatch returns
  `{:error, "Invalid internal price check digit"}`. A scheme with `check: nil`
  skips this validation. This mod-10-over-the-embedded-field rule is an
  illustrative convention for the shipped schemes — real region/retailer schemes
  may use a different price-check algorithm (see `ExGtin.RCN.Schemes`).

  Accepts a digit string, a non-negative integer, or a list of single digits.

  ## Examples

      iex> ExGtin.RCN.decode("2123451789012", :gs1_germany_price)
      {:ok, %{item: "12345", embedded: %{price: "78901"}}}

      iex> ExGtin.RCN.decode("2123456789012", :gs1_embedded_weight)
      {:ok, %{item: "123456", embedded: %{weight: "78901"}}}

      iex> scheme = %{prefix: ["2"], item: 2..6, embedded: {:price, 8..12}, check: nil}
      iex> ExGtin.RCN.decode("2123456789012", scheme)
      {:ok, %{item: "12345", embedded: %{price: "78901"}}}

      iex> ExGtin.RCN.decode("2123456789012", :gs1_germany_price)
      {:error, "Invalid internal price check digit"}

      iex> ExGtin.RCN.decode("2123456789012", :no_such_scheme)
      {:error, "Unknown RCN scheme: :no_such_scheme"}

      iex> ExGtin.RCN.decode("21234", :gs1_germany_price)
      {:error, "Code must be a 13-digit GTIN-13"}

  """
  @doc since: "1.5.0"
  @spec decode(code, scheme) :: {:ok, rcn_parsed} | {:error, String.t()}
  def decode(code, scheme) when is_atom(scheme) do
    with {:ok, resolved} <- Schemes.fetch(scheme) do
      decode(code, resolved)
    end
  end

  def decode(code, scheme) when is_map(scheme) do
    with {:ok, digits} <- normalize_gtin13(code),
         :ok <- check_scheme_prefix(digits, scheme),
         :ok <- check_internal_digit(digits, scheme) do
      {:ok, build_decoded(digits, scheme)}
    end
  end

  # Normalizes any accepted `code` input to a 13-element list of digit
  # characters, rejecting non-digit input and anything that is not exactly a
  # GTIN-13.
  @spec normalize_gtin13(code) :: {:ok, [String.t()]} | {:error, String.t()}
  defp normalize_gtin13(code) when is_bitstring(code) do
    cond do
      not String.match?(code, ~r/\A\d+\z/) ->
        {:error, "Code contains non-digit characters"}

      String.length(code) != @gtin13_length ->
        {:error, "Code must be a 13-digit GTIN-13"}

      true ->
        {:ok, String.codepoints(code)}
    end
  end

  defp normalize_gtin13(code) when is_integer(code) and code >= 0,
    do: normalize_gtin13(code |> Integer.digits() |> Enum.map_join(&Integer.to_string/1))

  defp normalize_gtin13(code) when is_integer(code),
    do: {:error, "Code must be a non-negative integer"}

  defp normalize_gtin13(code) when is_list(code) do
    if Enum.all?(code, fn d -> is_integer(d) and d in 0..9 end) do
      code |> Enum.map_join(&Integer.to_string/1) |> normalize_gtin13()
    else
      {:error, "Code contains non-digit values"}
    end
  end

  # Basic prefix guard: the code's leading digit must be listed in the scheme's
  # `prefix`. Full scheme/prefix-mismatch and check-digit handling is layered on
  # separately.
  @spec check_scheme_prefix([String.t()], Schemes.rcn_scheme()) ::
          :ok | {:error, String.t()}
  defp check_scheme_prefix(digits, %{prefix: prefixes}) do
    code = Enum.join(digits)

    if Enum.any?(prefixes, fn p -> String.starts_with?(code, p) end) do
      :ok
    else
      {:error, "Code prefix does not match scheme"}
    end
  end

  # Validates the scheme's internal price/weight check digit, when it declares
  # one. A scheme with `check: nil` skips this step (returns `:ok`).
  #
  # The shipped schemes use an **illustrative convention**: the internal check
  # digit at the named position is a standard GS1 mod-10 check digit computed —
  # via the library's shared `ExGtin.CheckDigit.mod10/1` engine — over the
  # embedded price/weight digit field. This keeps the internal check consistent
  # with the rest of the library and self-consistent for testing. Real region or
  # retailer schemes may define a different price-check algorithm; a caller whose
  # market uses a different rule should supply a scheme with `check: nil` and
  # validate the digit themselves.
  @spec check_internal_digit([String.t()], Schemes.rcn_scheme()) ::
          :ok | {:error, String.t()}
  defp check_internal_digit(_digits, %{check: nil}), do: :ok

  defp check_internal_digit(digits, %{
         check: {:price_check, position},
         embedded: {_kind, embedded_range}
       }) do
    embedded_digits =
      digits
      |> slice_positions(embedded_range)
      |> String.codepoints()
      |> Enum.map(&String.to_integer/1)

    expected = ExGtin.CheckDigit.mod10(embedded_digits)
    actual = digits |> Enum.at(position - 1) |> String.to_integer()

    if expected == actual do
      :ok
    else
      {:error, "Invalid internal price check digit"}
    end
  end

  # Builds the decoded result map by slicing the item and embedded digit ranges
  # out of the 13-digit code and tagging the embedded value with the scheme's
  # `:price`/`:weight` key.
  @spec build_decoded([String.t()], Schemes.rcn_scheme()) :: rcn_parsed
  defp build_decoded(digits, %{item: item_range, embedded: {kind, embedded_range}}) do
    %{
      item: slice_positions(digits, item_range),
      embedded: %{kind => slice_positions(digits, embedded_range)}
    }
  end

  # Extracts the digits at a 1-based, inclusive position `range` and joins them
  # back into a string.
  @spec slice_positions([String.t()], Range.t()) :: String.t()
  defp slice_positions(digits, first..last//_) do
    digits
    |> Enum.slice((first - 1)..(last - 1))
    |> Enum.join()
  end

  @doc """
  Returns whether `code` carries a restricted-circulation prefix.

  Returns `{:ok, boolean}` for a decodable digit sequence, or
  `{:error, reason}` when the input cannot be read as digits.

  Accepts a digit string, a non-negative integer, or a list of single digits.

  ## Examples

      iex> ExGtin.RCN.rcn_prefix?("2001234500009")
      {:ok, true}

      iex> ExGtin.RCN.rcn_prefix?("6291041500213")
      {:ok, false}

      iex> ExGtin.RCN.rcn_prefix?("12")
      {:error, "Code is too short to have a GS1 prefix"}

      iex> ExGtin.RCN.rcn_prefix?("20A1234500009")
      {:error, "Code contains non-digit characters"}

  """
  @doc since: "1.5.0"
  @spec rcn_prefix?(code) :: {:ok, boolean} | {:error, String.t()}
  def rcn_prefix?(code) when is_bitstring(code) do
    if String.match?(code, ~r/\A\d+\z/) do
      code
      |> String.codepoints()
      |> Enum.map(&String.to_integer/1)
      |> rcn_prefix?()
    else
      {:error, "Code contains non-digit characters"}
    end
  end

  def rcn_prefix?(code) when is_integer(code) and code >= 0,
    do: rcn_prefix?(Integer.digits(code))

  def rcn_prefix?(code) when is_integer(code),
    do: {:error, "Code must be a non-negative integer"}

  def rcn_prefix?(code) when is_list(code) do
    with {:ok, prefix} <- leading_prefix(code) do
      {:ok, Enum.any?(@rcn_prefix_ranges, fn range -> prefix in range end)}
    end
  end

  # Reads the leading three digits of a digit list as an integer prefix,
  # matching the 3-digit granularity of the GS1 prefix table.
  @spec leading_prefix([integer]) :: {:ok, integer} | {:error, String.t()}
  defp leading_prefix(digits) do
    cond do
      Enum.any?(digits, fn d -> not (is_integer(d) and d in 0..9) end) ->
        {:error, "Code contains non-digit values"}

      length(digits) < 3 ->
        {:error, "Code is too short to have a GS1 prefix"}

      true ->
        {:ok, Integer.undigits(Enum.take(digits, 3))}
    end
  end
end
