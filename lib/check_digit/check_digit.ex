defmodule ExGtin.CheckDigit do
  @moduledoc """
  Shared GS1 mod-10 check-digit engine operating purely on digit lists.

  Every GS1 identifier key (GTIN, GLN, SSCC, GSIN, ...) shares the same mod-10
  check-digit math; only length and formatting differ. This module owns that one
  tested implementation so the identifier features can build on it without
  copy-pasting the algorithm.

  It operates on digit lists (`list(0..9)`) so it is length-agnostic and reusable
  by every key type. String/integer coercion stays in the caller layers, matching
  the existing `ExGtin.Validation` boundary.

  The arithmetic delegates to `ExGtin.Validation.multiply_and_sum_array/1`
  (reversed-index weighting) and
  `ExGtin.Validation.subtract_from_nearest_multiple_of_ten/1`, so results are
  identical to the pre-refactor GTIN implementation.
  """
  @moduledoc since: "1.4.0"

  @doc """
  Computes the GS1 mod-10 check digit (`0..9`) for a digit-list body.

  ## Examples

      iex> ExGtin.CheckDigit.mod10([6, 2, 9, 1, 0, 4, 1, 5, 0, 0, 2, 1])
      3

  """
  @doc since: "1.4.0"
  @spec mod10(list(0..9)) :: 0..9
  def mod10(body) do
    body
    |> ExGtin.Validation.multiply_and_sum_array()
    |> ExGtin.Validation.subtract_from_nearest_multiple_of_ten()
  end

  @doc """
  Reports whether the last element of the digit list is the valid check digit
  for the preceding body.

  ## Examples

      iex> ExGtin.CheckDigit.valid?([6, 2, 9, 1, 0, 4, 1, 5, 0, 0, 2, 1, 3])
      true

      iex> ExGtin.CheckDigit.valid?([6, 2, 9, 1, 0, 4, 1, 5, 0, 0, 2, 1, 4])
      false

  """
  @doc since: "1.4.0"
  @spec valid?(list(0..9)) :: boolean
  def valid?(digits) do
    {body, [check_digit]} = Enum.split(digits, length(digits) - 1)
    mod10(body) == check_digit
  end

  @doc """
  Returns the digit-list body with its computed check digit appended.

  ## Examples

      iex> ExGtin.CheckDigit.append([6, 2, 9, 1, 0, 4, 1, 5, 0, 0, 2, 1])
      [6, 2, 9, 1, 0, 4, 1, 5, 0, 0, 2, 1, 3]

  """
  @doc since: "1.4.0"
  @spec append(list(0..9)) :: list(0..9)
  def append(body) do
    body ++ [mod10(body)]
  end
end
