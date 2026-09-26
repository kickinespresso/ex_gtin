defmodule ExGtin.Convert.GTIN14 do
  @moduledoc """
  GTIN-14 down-conversion to its base GTIN-13 / GTIN-12 form.

  A GTIN-14 is a base GTIN prefixed with a one-digit **indicator** that marks a
  packaging level (case, pallet, ...). Only an indicator of `0` denotes the
  base trade item itself: stripping that leading `0` recovers the underlying
  GTIN-13, and the mod-10 check digit stays valid because removing a leading
  zero does not change the weighted sum. A non-zero indicator identifies a
  distinct packaging item with no single base GTIN-13, so those inputs error.

  `to_gtin12/1` goes one step further: after recovering the 13-digit form it
  strips the next leading zero (present on GTIN-12-derived codes) to recover the
  GTIN-12. Every result is re-validated as a safety net.

  Inputs may be a `String`, an integer, or a digit list, matching the rest of
  the `ExGtin` API.

  > #### Integer leading-zero caveat {: .warning}
  >
  > A GTIN-14 with indicator `0` begins with a leading zero, which an integer
  > input silently drops (e.g. `06291041500213` becomes the 13-digit
  > `6291041500213`). Supply such codes as a `String` or digit list to preserve
  > length.
  """
  @moduledoc since: "1.4.0"

  @doc """
  Reduces a GTIN-14 with indicator `0` to its base GTIN-13.

  Validates the input as a GTIN-14, then reads the leading indicator digit. When
  the indicator is `0`, the leading zero is stripped and the remaining 13 digits
  (whose mod-10 check digit is unchanged) are re-validated as a GTIN-13.

  Returns `{:ok, gtin13}` on success. Returns
  `{:error, "GTIN-14 indicator is not 0; no base GTIN-13"}` when the indicator
  is in `1..9`, or an `{:error, _}` tuple when the input is not a valid GTIN-14.

  ## Examples

      iex> ExGtin.Convert.GTIN14.to_gtin13("06291041500213")
      {:ok, "6291041500213"}

      iex> ExGtin.Convert.GTIN14.to_gtin13("16291041500210")
      {:error, "GTIN-14 indicator is not 0; no base GTIN-13"}

  """
  @doc since: "1.4.0"
  @spec to_gtin13(String.t() | integer | list(0..9)) ::
          {:ok, String.t()} | {:error, String.t()}
  def to_gtin13(gtin14) do
    with {:ok, digits} <- to_gtin14_digits(gtin14),
         {:ok, [_indicator | rest]} <- require_zero_indicator(digits),
         gtin13 = Enum.join(rest),
         {:ok, "GTIN-13"} <- ExGtin.validate(gtin13) do
      {:ok, gtin13}
    end
  end

  @doc """
  Reduces a GTIN-14 with indicator `0` to its base GTIN-12.

  Behaves like `to_gtin13/1` and additionally strips the next leading zero of
  the recovered 13-digit form to obtain the 12-digit body, re-validating the
  result as a GTIN-12.

  Returns `{:ok, gtin12}` on success. Returns
  `{:error, "GTIN-14 indicator is not 0; no base GTIN-13"}` when the indicator
  is in `1..9`, and `{:error, "GTIN-14 has no base GTIN-12"}` when the 13-digit
  form's next digit is not `0` (so no GTIN-12 exists).

  ## Examples

      iex> ExGtin.Convert.GTIN14.to_gtin12("00012345000010")
      {:ok, "012345000010"}

      iex> ExGtin.Convert.GTIN14.to_gtin12("06291041500213")
      {:error, "GTIN-14 has no base GTIN-12"}

      iex> ExGtin.Convert.GTIN14.to_gtin12("16291041500210")
      {:error, "GTIN-14 indicator is not 0; no base GTIN-13"}

  """
  @doc since: "1.4.0"
  @spec to_gtin12(String.t() | integer | list(0..9)) ::
          {:ok, String.t()} | {:error, String.t()}
  def to_gtin12(gtin14) do
    with {:ok, digits} <- to_gtin14_digits(gtin14),
         {:ok, [_indicator | rest]} <- require_zero_indicator(digits),
         {:ok, [_leading_zero | body]} <- require_zero_lead(rest),
         gtin12 = Enum.join(body),
         {:ok, "GTIN-12"} <- ExGtin.validate(gtin12) do
      {:ok, gtin12}
    end
  end

  # Coerces String / integer / digit-list input to a 14-digit list, validating
  # it as a GTIN-14 first so malformed or wrong-length input errors uniformly.
  @spec to_gtin14_digits(String.t() | integer | list(0..9)) ::
          {:ok, list(0..9)} | {:error, String.t()}
  defp to_gtin14_digits(gtin14) when is_bitstring(gtin14) do
    case ExGtin.validate(gtin14) do
      {:ok, "GTIN-14"} -> parse_digits(gtin14)
      {:ok, type} -> {:error, "Expected GTIN-14, got #{type}"}
      {:error, reason} -> {:error, reason}
    end
  end

  defp to_gtin14_digits(gtin14) when is_integer(gtin14),
    do: to_gtin14_digits(Integer.to_string(gtin14))

  defp to_gtin14_digits(gtin14) when is_list(gtin14),
    do: to_gtin14_digits(Enum.join(gtin14))

  defp to_gtin14_digits(_), do: {:error, "Invalid GTIN-14 input"}

  # Parses a validated string into a digit list.
  @spec parse_digits(String.t()) :: {:ok, list(0..9)}
  defp parse_digits(string) do
    digits = string |> String.codepoints() |> Enum.map(&String.to_integer/1)
    {:ok, digits}
  end

  # Requires the indicator (first) digit to be 0; otherwise there is no base
  # GTIN-13 for the code.
  @spec require_zero_indicator(list(0..9)) :: {:ok, list(0..9)} | {:error, String.t()}
  defp require_zero_indicator([0 | _rest] = digits), do: {:ok, digits}
  defp require_zero_indicator(_), do: {:error, "GTIN-14 indicator is not 0; no base GTIN-13"}

  # Requires the next leading digit to be 0 so a GTIN-12 exists after stripping.
  @spec require_zero_lead(list(0..9)) :: {:ok, list(0..9)} | {:error, String.t()}
  defp require_zero_lead([0 | _rest] = digits), do: {:ok, digits}
  defp require_zero_lead(_), do: {:error, "GTIN-14 has no base GTIN-12"}
end
