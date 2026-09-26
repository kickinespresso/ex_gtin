defmodule ExGtin.Convert.UPC do
  @moduledoc """
  UPC-E ⇄ UPC-A conversion built on the shared mod-10 check-digit engine.

  A UPC-E is the zero-suppressed (compressed) form of a UPC-A. Expansion is a
  pure, table-driven transform keyed on the **6th digit of the 6-digit UPC-E
  body**: the `0`/`1`/`2`, `3`, `4`, and `5`–`9` branches each reinsert a
  different run of zeros to rebuild the 10-digit manufacturer + item section.

  Only number systems `0` and `1` are eligible for UPC-E; any other number
  system yields an error. The UPC-A check digit is always **recomputed** via
  `ExGtin.CheckDigit` rather than trusted from the UPC-E input, so malformed
  inputs surface as invalid downstream.

  Inputs may be a `String`, an integer, or a digit list, matching the rest of
  the `ExGtin` API.

  > #### Integer leading-zero caveat {: .warning}
  >
  > A UPC-E always begins with number system `0` or `1`. When passed as an
  > integer, a leading `0` is lost (e.g. `01234565` becomes `1234565`, seven
  > digits), so number-system-`0` codes must be supplied as a `String` or digit
  > list to preserve length.
  """
  @moduledoc since: "1.4.0"

  @doc """
  Expands a UPC-E code into its full 12-digit UPC-A form.

  Validates that the input is exactly 8 digits with number system `0` or `1`,
  applies the zero-suppression expansion rule selected by the 6th body digit,
  and appends a freshly computed check digit.

  Returns `{:ok, upca}` on success, or `{:error, reason}` when the number system
  is not `0`/`1`, the length is not 8, or the input is non-numeric.

  ## Examples

      iex> ExGtin.Convert.UPC.upce_to_upca("01234565")
      {:ok, "012345000065"}

      iex> ExGtin.Convert.UPC.upce_to_upca("00000000")
      {:ok, "000000000000"}

      iex> ExGtin.Convert.UPC.upce_to_upca("04250000")
      {:ok, "042000005005"}

      iex> ExGtin.Convert.UPC.upce_to_upca("21234560")
      {:error, "UPC-E number system must be 0 or 1"}

      iex> ExGtin.Convert.UPC.upce_to_upca("1234567")
      {:error, "Invalid UPC-E length"}

  """
  @doc since: "1.4.0"
  @spec upce_to_upca(String.t() | integer | list(0..9)) ::
          {:ok, String.t()} | {:error, String.t()}
  def upce_to_upca(upce) when is_bitstring(upce) do
    case parse_digits(upce) do
      {:ok, digits} -> upce_to_upca(digits)
      {:error, reason} -> {:error, reason}
    end
  end

  def upce_to_upca(upce) when is_integer(upce), do: upce_to_upca(Integer.digits(upce))

  def upce_to_upca(upce) when is_list(upce) do
    with {:ok, digits} <- validate_length(upce),
         {:ok, {number_system, body, _check}} <- split(digits),
         {:ok, expanded} <- expand(number_system, body) do
      body_digits = [number_system] ++ expanded

      upca =
        body_digits
        |> ExGtin.CheckDigit.append()
        |> Enum.join()

      {:ok, upca}
    end
  end

  def upce_to_upca(_), do: {:error, "Invalid UPC-E input"}

  @doc """
  Compresses a full 12-digit UPC-A into its 8-digit UPC-E form.

  This is the exact inverse of the zero-suppression expansion in
  `upce_to_upca/1`: it recognizes the zero-run pattern produced by each expansion
  branch and rebuilds the 6-digit UPC-E body. The UPC-A check digit is carried
  through as the UPC-E's trailing digit, so `upca_to_upce(upce_to_upca(x))`
  round-trips exactly (`upce_to_upca/1` recomputes that shared check digit).

  Validates that the input is exactly 12 digits with number system `0` or `1`.
  Returns `{:ok, upce}` when a compression rule matches, or
  `{:error, "UPC-A is not compressible to UPC-E"}` when no zero-run pattern
  applies. Wrong-length, non-numeric, or ineligible number-system inputs return
  an `{:error, _}` tuple.

  ## Examples

      iex> ExGtin.Convert.UPC.upca_to_upce("012345000065")
      {:ok, "01234565"}

      iex> ExGtin.Convert.UPC.upca_to_upce("042000005005")
      {:ok, "04250005"}

      iex> ExGtin.Convert.UPC.upca_to_upce("012345678905")
      {:error, "UPC-A is not compressible to UPC-E"}

      iex> ExGtin.Convert.UPC.upca_to_upce("21234560000")
      {:error, "Invalid UPC-A length"}

      iex> {:ok, upca} = ExGtin.Convert.UPC.upce_to_upca("01234565")
      iex> ExGtin.Convert.UPC.upca_to_upce(upca)
      {:ok, "01234565"}

  """
  @doc since: "1.4.0"
  @spec upca_to_upce(String.t() | integer | list(0..9)) ::
          {:ok, String.t()} | {:error, String.t()}
  def upca_to_upce(upca) when is_bitstring(upca) do
    case parse_digits_upca(upca) do
      {:ok, digits} -> upca_to_upce(digits)
      {:error, reason} -> {:error, reason}
    end
  end

  def upca_to_upce(upca) when is_integer(upca), do: upca_to_upce(Integer.digits(upca))

  def upca_to_upce(upca) when is_list(upca) do
    with {:ok, digits} <- validate_length_upca(upca),
         {:ok, {number_system, section, check}} <- split_upca(digits),
         {:ok, body} <- compress(section) do
      upce = ([number_system] ++ body ++ [check]) |> Enum.join()
      {:ok, upce}
    end
  end

  def upca_to_upce(_), do: {:error, "Invalid UPC-A input"}

  # Parses a UPC-A string into a digit list, rejecting non-digit characters.
  @spec parse_digits_upca(String.t()) :: {:ok, list(0..9)} | {:error, String.t()}
  defp parse_digits_upca(string) do
    string
    |> String.codepoints()
    |> Enum.reduce_while({:ok, []}, fn char, {:ok, acc} ->
      case Integer.parse(char) do
        {digit, ""} -> {:cont, {:ok, acc ++ [digit]}}
        _ -> {:halt, {:error, "UPC-A must contain only digits"}}
      end
    end)
  end

  @spec validate_length_upca(list(0..9)) :: {:ok, list(0..9)} | {:error, String.t()}
  defp validate_length_upca(digits) when length(digits) == 12, do: {:ok, digits}
  defp validate_length_upca(_), do: {:error, "Invalid UPC-A length"}

  # Splits a 12-digit UPC-A into {number_system, 10-digit section, check_digit},
  # rejecting number systems other than 0 or 1 (the only UPC-E-eligible ones).
  @spec split_upca(list(0..9)) ::
          {:ok, {0..1, list(0..9), 0..9}} | {:error, String.t()}
  defp split_upca([number_system | _rest]) when number_system not in [0, 1],
    do: {:error, "UPC-A number system must be 0 or 1"}

  defp split_upca([number_system | rest]) do
    {section, [check]} = Enum.split(rest, 10)
    {:ok, {number_system, section, check}}
  end

  # Table-driven zero-run recognition: the exact inverse of expand/2. Each clause
  # matches the zero pattern a forward branch produced and rebuilds the 6-digit
  # UPC-E body. Clauses are ordered/guarded so exactly one forward branch is
  # recoverable, preserving the round-trip guarantee.
  @spec compress(list(0..9)) :: {:ok, list(0..9)} | {:error, String.t()}
  # Inverse of last in {0,1,2}: [m1,m2,last,0,0,0,0,m3,m4,m5]
  defp compress([m1, m2, last, 0, 0, 0, 0, m3, m4, m5]) when last in [0, 1, 2],
    do: {:ok, [m1, m2, m3, m4, m5, last]}

  # Inverse of last = 3: [m1,m2,m3,0,0,0,0,0,m4,m5]
  defp compress([m1, m2, m3, 0, 0, 0, 0, 0, m4, m5]),
    do: {:ok, [m1, m2, m3, m4, m5, 3]}

  # Inverse of last = 4: [m1,m2,m3,m4,0,0,0,0,0,m5]
  defp compress([m1, m2, m3, m4, 0, 0, 0, 0, 0, m5]),
    do: {:ok, [m1, m2, m3, m4, m5, 4]}

  # Inverse of last in {5..9}: [m1,m2,m3,m4,m5,0,0,0,0,last]
  defp compress([m1, m2, m3, m4, m5, 0, 0, 0, 0, last]) when last in [5, 6, 7, 8, 9],
    do: {:ok, [m1, m2, m3, m4, m5, last]}

  defp compress(_), do: {:error, "UPC-A is not compressible to UPC-E"}

  # Parses a string into a digit list, rejecting any non-digit character.
  @spec parse_digits(String.t()) :: {:ok, list(0..9)} | {:error, String.t()}
  defp parse_digits(string) do
    string
    |> String.codepoints()
    |> Enum.reduce_while({:ok, []}, fn char, {:ok, acc} ->
      case Integer.parse(char) do
        {digit, ""} -> {:cont, {:ok, acc ++ [digit]}}
        _ -> {:halt, {:error, "UPC-E must contain only digits"}}
      end
    end)
  end

  @spec validate_length(list(0..9)) :: {:ok, list(0..9)} | {:error, String.t()}
  defp validate_length(digits) when length(digits) == 8, do: {:ok, digits}
  defp validate_length(_), do: {:error, "Invalid UPC-E length"}

  # Splits an 8-digit UPC-E into {number_system, 6-digit body, check_digit},
  # rejecting number systems other than 0 or 1.
  @spec split(list(0..9)) :: {:ok, {0..1, list(0..9), 0..9}} | {:error, String.t()}
  defp split([number_system | _rest]) when number_system not in [0, 1],
    do: {:error, "UPC-E number system must be 0 or 1"}

  defp split([number_system | rest]) do
    {body, [check]} = Enum.split(rest, 6)
    {:ok, {number_system, body, check}}
  end

  # Table-driven zero-suppression expansion keyed on the 6th body digit.
  # Rebuilds the 10-digit manufacturer + item section of the UPC-A.
  @spec expand(0..1, list(0..9)) :: {:ok, list(0..9)}
  defp expand(_number_system, [m1, m2, m3, m4, m5, last]) do
    expanded =
      case last do
        d when d in [0, 1, 2] -> [m1, m2, last, 0, 0, 0, 0, m3, m4, m5]
        3 -> [m1, m2, m3, 0, 0, 0, 0, 0, m4, m5]
        4 -> [m1, m2, m3, m4, 0, 0, 0, 0, 0, m5]
        d when d in [5, 6, 7, 8, 9] -> [m1, m2, m3, m4, m5, 0, 0, 0, 0, last]
      end

    {:ok, expanded}
  end
end
