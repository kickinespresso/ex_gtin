defmodule ExGtin.Fix do
  @moduledoc """
  Best-effort correction of nearly-valid GTIN codes.

  Real-world GTIN data is frequently damaged in two mechanical ways that carry
  no information loss and are safe to repair:

    * **Leading zeros are dropped** when a code is stored or transported as an
      integer rather than a string (for example `87248795257` for the 12-digit
      `087248795257`); and
    * **Surrounding whitespace** is introduced by manual entry, spreadsheet
      export, or scanner glue (for example `"6291041500213\\n"`).

  `fix/2` (and the length-inferring `fix/1`) undo exactly those two mutations —
  it trims whitespace and left-pads with zeros to the target GTIN length — and
  then re-validates the mod-10 check digit. It never invents or alters a
  significant digit and never touches the check digit, so a successful result is
  a genuinely valid GTIN, not a fabricated one.

  Anything beyond those safe repairs is reported as a structured error atom
  rather than a string, so callers can branch on the cause:

    * `:non_numeric` — the input contained a non-digit character after trimming
    * `:too_long` — the trimmed input is already longer than the target length,
      so zero-padding cannot help
    * `:invalid_length` — (only from `fix/1`) the trimmed input is longer than
      the largest supported GTIN length (14)
    * `:check_digit_incorrect` — the code is the right length and all digits, but
      its check digit does not match, so the damage is not a recoverable
      length/whitespace issue

  This mirrors the correction behavior of the Rust `gtin-validate` crate's
  `fix` functions while fitting the `{:ok, _} | {:error, _}` conventions used
  across `ExGtin`.
  """
  @moduledoc since: "1.6.0"

  @typedoc "The supported fixed GTIN lengths."
  @type gtin_length :: 8 | 12 | 13 | 14

  @typedoc "A target GTIN length, either the digit count or its named atom."
  @type target :: gtin_length | :gtin8 | :gtin12 | :gtin13 | :gtin14

  @typedoc "Structured reasons a code could not be corrected."
  @type reason :: :non_numeric | :too_long | :invalid_length | :check_digit_incorrect

  @gtin_lengths [8, 12, 13, 14]

  @length_for_atom %{gtin8: 8, gtin12: 12, gtin13: 13, gtin14: 14}

  @doc """
  Corrects a nearly-valid code, inferring the target GTIN length.

  Trims surrounding whitespace, then chooses the smallest supported GTIN length
  (8, 12, 13, 14) that the trimmed digit string fits into and zero-pads to it.
  For example a trimmed length of 11 or 12 targets GTIN-12, while 13 targets
  GTIN-13. After padding, the mod-10 check digit is re-validated.

  Returns `{:ok, corrected}` or `{:error, reason}` (see the module doc for the
  `t:reason/0` values). A trimmed input longer than 14 digits yields
  `{:error, :invalid_length}`.

  ## Examples

      iex> ExGtin.Fix.fix("87248795257")
      {:ok, "087248795257"}

      iex> ExGtin.Fix.fix(" 6291041500213 ")
      {:ok, "6291041500213"}

      iex> ExGtin.Fix.fix("0")
      {:ok, "00000000"}

      iex> ExGtin.Fix.fix("123456789013")
      {:error, :check_digit_incorrect}

      iex> ExGtin.Fix.fix("123412341234123")
      {:error, :invalid_length}

  """
  @doc since: "1.6.0"
  @spec fix(String.t() | integer | list(0..9)) :: {:ok, String.t()} | {:error, reason}
  def fix(code) do
    with {:ok, trimmed} <- normalize_input(code),
         {:ok, length} <- infer_length(trimmed) do
      pad_and_validate(trimmed, length)
    end
  end

  @doc """
  Corrects a nearly-valid code to a specific target GTIN length.

  `target` is either a supported length integer (`8`, `12`, `13`, `14`) or its
  named atom (`:gtin8`, `:gtin12`, `:gtin13`, `:gtin14`). Trims surrounding
  whitespace, left-pads with zeros to `target`, then re-validates the mod-10
  check digit.

  Returns `{:ok, corrected}` or `{:error, reason}`. A trimmed input already
  longer than `target` yields `{:error, :too_long}`.

  ## Examples

      iex> ExGtin.Fix.fix("495205944325", 13)
      {:ok, "0495205944325"}

      iex> ExGtin.Fix.fix("495205944325", :gtin13)
      {:ok, "0495205944325"}

      iex> ExGtin.Fix.fix("0", 14)
      {:ok, "00000000000000"}

      iex> ExGtin.Fix.fix("0000000000000", 12)
      {:error, :too_long}

      iex> ExGtin.Fix.fix("8845791354262", 13)
      {:error, :check_digit_incorrect}

  """
  @doc since: "1.6.0"
  @spec fix(String.t() | integer | list(0..9), target) :: {:ok, String.t()} | {:error, reason}
  def fix(code, target) do
    length = resolve_target(target)

    with {:ok, trimmed} <- normalize_input(code) do
      pad_and_validate(trimmed, length)
    end
  end

  @doc """
  The raising variant of `fix/1`: returns the corrected string or raises
  `ArgumentError` with the failure reason.

  ## Examples

      iex> ExGtin.Fix.fix!("87248795257")
      "087248795257"

  """
  @doc since: "1.6.0"
  @spec fix!(String.t() | integer | list(0..9)) :: String.t()
  def fix!(code), do: unwrap(fix(code))

  @doc """
  The raising variant of `fix/2`: returns the corrected string or raises
  `ArgumentError` with the failure reason.

  ## Examples

      iex> ExGtin.Fix.fix!("495205944325", 13)
      "0495205944325"

  """
  @doc since: "1.6.0"
  @spec fix!(String.t() | integer | list(0..9), target) :: String.t()
  def fix!(code, target), do: unwrap(fix(code, target))

  # -- internals -------------------------------------------------------------

  # Coerces the accepted input shapes to a trimmed digit string, rejecting any
  # non-digit content (after trimming) with `:non_numeric`. Integers and digit
  # lists carry no whitespace; strings are trimmed on both sides.
  @spec normalize_input(String.t() | integer | list(0..9)) ::
          {:ok, String.t()} | {:error, :non_numeric}
  defp normalize_input(code) when is_integer(code) and code >= 0,
    do: {:ok, Integer.to_string(code)}

  defp normalize_input(code) when is_integer(code), do: {:error, :non_numeric}

  defp normalize_input(code) when is_list(code) do
    if Enum.all?(code, &(is_integer(&1) and &1 in 0..9)) do
      {:ok, Enum.join(code)}
    else
      {:error, :non_numeric}
    end
  end

  defp normalize_input(code) when is_binary(code) do
    trimmed = String.trim(code)

    if trimmed != "" and String.match?(trimmed, ~r/\A[0-9]+\z/) do
      {:ok, trimmed}
    else
      {:error, :non_numeric}
    end
  end

  defp normalize_input(_code), do: {:error, :non_numeric}

  # Picks the smallest supported GTIN length that can hold the trimmed digits.
  @spec infer_length(String.t()) :: {:ok, gtin_length} | {:error, :invalid_length}
  defp infer_length(trimmed) do
    len = String.length(trimmed)

    case Enum.find(@gtin_lengths, &(&1 >= len)) do
      nil -> {:error, :invalid_length}
      length -> {:ok, length}
    end
  end

  @spec resolve_target(target) :: gtin_length
  defp resolve_target(target) when target in @gtin_lengths, do: target

  defp resolve_target(target) when is_map_key(@length_for_atom, target),
    do: @length_for_atom[target]

  defp resolve_target(target) do
    raise ArgumentError,
      message:
        "Invalid GTIN target #{inspect(target)}; expected one of 8, 12, 13, 14 " <>
          "or :gtin8, :gtin12, :gtin13, :gtin14"
  end

  # Left-pads to the target length (rejecting an already-too-long input) and
  # re-validates the check digit.
  @spec pad_and_validate(String.t(), gtin_length) :: {:ok, String.t()} | {:error, reason}
  defp pad_and_validate(trimmed, length) do
    if String.length(trimmed) > length do
      {:error, :too_long}
    else
      padded = String.pad_leading(trimmed, length, "0")

      case ExGtin.validate(padded) do
        {:ok, _type} -> {:ok, padded}
        {:error, _reason} -> {:error, :check_digit_incorrect}
      end
    end
  end

  @spec unwrap({:ok, String.t()} | {:error, reason}) :: String.t()
  defp unwrap({:ok, corrected}), do: corrected
  defp unwrap({:error, reason}), do: raise(ArgumentError, message: to_string(reason))
end
