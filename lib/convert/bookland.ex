defmodule ExGtin.Convert.Bookland do
  @moduledoc """
  Bookland conversion between ISBN-10 and ISBN-13 (and ISSN support).

  Bookland is the GS1 arrangement that carries book identifiers in the `978`
  and `979` prefix ranges. An ISBN-13 is a GTIN-13 that uses the shared mod-10
  check-digit engine, while an ISBN-10 uses its own mod-11 check whose value can
  be `X` (10). This module hosts the conversions between the two forms and reuses
  the mod-11 logic already present in `ExGtin.Validation.valid_isbn10?/1`.

  Inputs may be a `String`, an integer, or a digit list, matching the rest of
  the `ExGtin` API.

  > #### Integer leading-zero caveat {: .warning}
  >
  > An ISBN-10 body may begin with a leading zero, which an integer input
  > silently drops. Supply such codes as a `String` or digit list to preserve
  > length.
  """
  @moduledoc since: "1.4.0"

  # Length of the ISBN-10 body (the ISBN-10 without its trailing check character).
  @isbn10_body_length 9

  @doc """
  Computes the ISBN-10 mod-11 check character for a 9-digit ISBN-10 body.

  Takes the 9-digit body (an ISBN-10 without its trailing check character) and
  returns the mod-11 check as a bare `0..9` integer, or the string `"X"` when the
  check value is 10. Returns an `{:error, _}` tuple when the body is not exactly
  9 digits or contains non-digit content.

  The algorithm mirrors `ExGtin.Validation.valid_isbn10?/1`: for the body digits
  with 0-based index `i`, `sum = Σ (10 - i) * digit`, and the check value `c`
  satisfies `rem(sum + c, 11) == 0`, i.e. `c = rem(11 - rem(sum, 11), 11)`; when
  `c == 10` the character is `"X"`.

  A bare value (rather than an `{:ok, _}` tuple) is returned on success so the
  ISBN-13 → ISBN-10 conversion in `isbn13_to_isbn10/1` can append the check
  directly to the body string without unwrapping.

  ## Examples

      iex> ExGtin.Convert.Bookland.isbn10_check_digit("030640615")
      2

      iex> ExGtin.Convert.Bookland.isbn10_check_digit("155860832")
      "X"

      iex> ExGtin.Convert.Bookland.isbn10_check_digit("12345")
      {:error, "Invalid ISBN-10 body"}

  """
  @doc since: "1.4.0"
  @spec isbn10_check_digit(String.t() | integer | list(0..9)) ::
          0..9 | String.t() | {:error, String.t()}
  def isbn10_check_digit(body) do
    with {:ok, digits} <- to_digits(body),
         {:ok, digits} <- require_isbn10_body(digits) do
      sum =
        digits
        |> Enum.with_index()
        |> Enum.reduce(0, fn {d, i}, acc -> acc + (10 - i) * d end)

      case rem(11 - rem(sum, 11), 11) do
        10 -> "X"
        c -> c
      end
    end
  end

  @doc """
  Converts a valid ISBN-10 into its ISBN-13 (`978`-prefixed) equivalent.

  The full 10-character input is validated as an ISBN-10 via
  `ExGtin.Validation.valid_isbn10?/1` (mod-11, trailing `X` allowed). On success
  the ISBN-13 is built by prepending `978` to the first 9 ISBN-10 digits and
  appending a freshly computed GS1 mod-10 check via `ExGtin.CheckDigit.append/1`.

  Returns `{:ok, isbn13}` or `{:error, "Invalid ISBN-10"}`.

  > #### Integer leading-zero caveat {: .warning}
  >
  > Because an integer input drops leading zeros, pass ISBN-10 codes that begin
  > with `0` as a `String`.

  ## Examples

      iex> ExGtin.Convert.Bookland.isbn10_to_isbn13("0306406152")
      {:ok, "9780306406157"}

      iex> ExGtin.Convert.Bookland.isbn10_to_isbn13("155860832X")
      {:ok, "9781558608320"}

      iex> ExGtin.Convert.Bookland.isbn10_to_isbn13("1234567890")
      {:error, "Invalid ISBN-10"}

  """
  @doc since: "1.4.0"
  @spec isbn10_to_isbn13(String.t() | integer | list(0..9)) ::
          {:ok, String.t()} | {:error, String.t()}
  def isbn10_to_isbn13(isbn10) do
    with {:ok, isbn10_string} <- to_isbn10_string(isbn10),
         true <- ExGtin.Validation.valid_isbn10?(isbn10_string) do
      body =
        [9, 7, 8] ++
          (isbn10_string
           |> String.slice(0, @isbn10_body_length)
           |> String.codepoints()
           |> Enum.map(&String.to_integer/1))

      {:ok, body |> ExGtin.CheckDigit.append() |> Enum.join()}
    else
      _ -> {:error, "Invalid ISBN-10"}
    end
  end

  @doc """
  Converts a `978`-prefixed ISBN-13 back into its ISBN-10 equivalent.

  The input must be a valid ISBN-13: exactly 13 digits with a `978` or `979`
  prefix and a valid GS1 mod-10 check (via `ExGtin.CheckDigit.valid?/1`). For a
  `978`-prefixed code the 9-digit body (digits 4–12, after the `978` prefix) is
  taken and a recomputed ISBN-10 mod-11 check is appended via
  `isbn10_check_digit/1`; that check may be `"X"`.

  A `979`-prefixed ISBN-13 has no ISBN-10 equivalent and returns
  `{:error, "ISBN-13 with 979 prefix has no ISBN-10 equivalent"}`. Any other
  invalid input returns `{:error, "Invalid ISBN-13"}`.

  Returns `{:ok, isbn10}` or an `{:error, _}` tuple.

  ## Examples

      iex> ExGtin.Convert.Bookland.isbn13_to_isbn10("9780306406157")
      {:ok, "0306406152"}

      iex> ExGtin.Convert.Bookland.isbn13_to_isbn10("9781558608320")
      {:ok, "155860832X"}

      iex> ExGtin.Convert.Bookland.isbn13_to_isbn10("9791234567896")
      {:error, "ISBN-13 with 979 prefix has no ISBN-10 equivalent"}

      iex> ExGtin.Convert.Bookland.isbn13_to_isbn10("9780306406158")
      {:error, "Invalid ISBN-13"}

  """
  @doc since: "1.4.0"
  @spec isbn13_to_isbn10(String.t() | integer | list(0..9)) ::
          {:ok, String.t()} | {:error, String.t()}
  def isbn13_to_isbn10(isbn13) do
    with {:ok, digits} <- to_digits(isbn13),
         true <- valid_isbn13?(digits) do
      reduce_valid_isbn13(digits)
    else
      _ -> {:error, "Invalid ISBN-13"}
    end
  end

  # Reduces an already-validated ISBN-13 to its ISBN-10 form. Only a
  # 978-prefixed code has an ISBN-10 equivalent; a 979 prefix does not.
  @spec reduce_valid_isbn13(list(0..9)) :: {:ok, String.t()} | {:error, String.t()}
  defp reduce_valid_isbn13([9, 7, 8 | _] = digits) do
    body = Enum.slice(digits, 3, @isbn10_body_length)

    case isbn10_check_digit(body) do
      {:error, error} -> {:error, error}
      check -> {:ok, Enum.join(body) <> to_string(check)}
    end
  end

  defp reduce_valid_isbn13(_digits),
    do: {:error, "ISBN-13 with 979 prefix has no ISBN-10 equivalent"}

  @doc """
  Validates an ISBN by dispatching on its length.

  A 10-character input is validated with the ISBN-10 mod-11 check (delegating to
  `ExGtin.Validation.valid_isbn10?/1`, trailing `X` allowed). A 13-digit input is
  validated as an ISBN-13: a `978`/`979` prefix with a valid GS1 mod-10 check.
  Any other length is invalid.

  Returns a `boolean`.

  ## Examples

      iex> ExGtin.Convert.Bookland.valid_isbn?("155860832X")
      true

      iex> ExGtin.Convert.Bookland.valid_isbn?("9780306406157")
      true

      iex> ExGtin.Convert.Bookland.valid_isbn?("1234567890")
      false

      iex> ExGtin.Convert.Bookland.valid_isbn?("9780306406158")
      false

  """
  @doc since: "1.4.0"
  @spec valid_isbn?(String.t() | integer | list(0..9)) :: boolean
  def valid_isbn?(isbn) do
    case to_isbn10_string(isbn) do
      {:ok, string} when byte_size(string) == 10 ->
        ExGtin.Validation.valid_isbn10?(string)

      _ ->
        case to_digits(isbn) do
          {:ok, digits} -> valid_isbn13?(digits)
          _ -> false
        end
    end
  end

  # A valid ISBN-13 is exactly 13 digits, carries a 978/979 prefix, and satisfies
  # the shared GS1 mod-10 check.
  @spec valid_isbn13?(list(0..9)) :: boolean
  defp valid_isbn13?([9, 7, p | _] = digits) when p in [8, 9] and length(digits) == 13,
    do: ExGtin.CheckDigit.valid?(digits)

  defp valid_isbn13?(_), do: false

  # Coerces String / integer / digit-list input to a canonical ISBN-10 candidate
  # string (digits plus an optional trailing X). Preserves the trailing X that a
  # digit-only coercion would reject, so valid_isbn10?/1 can judge it.
  @spec to_isbn10_string(String.t() | integer | list(0..9)) ::
          {:ok, String.t()} | {:error, String.t()}
  defp to_isbn10_string(code) when is_bitstring(code), do: {:ok, code}

  defp to_isbn10_string(code) when is_integer(code) and code >= 0,
    do: {:ok, code |> Integer.digits() |> Enum.join()}

  defp to_isbn10_string(code) when is_list(code) do
    if Enum.all?(code, &(is_integer(&1) and &1 in 0..9)) do
      {:ok, Enum.join(code)}
    else
      {:error, "Invalid ISBN-10"}
    end
  end

  defp to_isbn10_string(_), do: {:error, "Invalid ISBN-10"}

  # Coerces String / integer / digit-list input to a digit list, rejecting any
  # non-digit content uniformly. Mirrors ExGtin.Keys.to_digits/1.
  @spec to_digits(String.t() | integer | list(0..9)) ::
          {:ok, list(0..9)} | {:error, String.t()}
  defp to_digits(code) when is_bitstring(code) do
    code
    |> String.codepoints()
    |> Enum.reduce_while({:ok, []}, fn c, {:ok, acc} ->
      case Integer.parse(c) do
        {n, ""} -> {:cont, {:ok, acc ++ [n]}}
        _ -> {:halt, {:error, "Invalid ISBN-10 body"}}
      end
    end)
  end

  defp to_digits(code) when is_integer(code) and code >= 0,
    do: {:ok, Integer.digits(code)}

  defp to_digits(code) when is_list(code) do
    case Enum.all?(code, &(is_integer(&1) and &1 in 0..9)) do
      true -> {:ok, code}
      false -> {:error, "Invalid ISBN-10 body"}
    end
  end

  defp to_digits(_), do: {:error, "Invalid ISBN-10 body"}

  # Requires the ISBN-10 body to be exactly 9 digits so a shorter or longer body
  # never falls through to the mod-11 calculation.
  @spec require_isbn10_body(list(0..9)) :: {:ok, list(0..9)} | {:error, String.t()}
  defp require_isbn10_body(digits) when length(digits) == @isbn10_body_length,
    do: {:ok, digits}

  defp require_isbn10_body(_digits), do: {:error, "Invalid ISBN-10 body"}
end
