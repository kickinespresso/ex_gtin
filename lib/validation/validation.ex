defmodule ExGtin.Validation do
  @moduledoc """
  Documentation for ExGtin. This library provides
  functionality for validating GTIN compliant codes.
  """

  @doc """
  Check for valid  GTIN-8, GTIN-12, GTIN-13, GTIN-14, GSIN, SSCC codes

  Returns `{:ok}` or `{:error}`

  ## Examples

      iex> ExGtin.Validation.gtin_check_digit("6291041500213")
      {:ok, "GTIN-13"}

      iex> ExGtin.Validation.gtin_check_digit("6291041500214")
      {:error, "Invalid Code"}
  """
  @spec gtin_check_digit(string) :: {atom, string}
  def gtin_check_digit(number) when is_bitstring(number) do
    number
      |> String.codepoints
      |> Enum.map(fn(x) -> String.to_integer(x) end)
      |> gtin_check_digit
  end

  @spec gtin_check_digit(number) :: {atom, string}
  def gtin_check_digit(number) when is_number(number), do: gtin_check_digit(Integer.digits(number))

  @spec gtin_check_digit(list(number)) :: {atom, string}
  def gtin_check_digit(number) do
    case check_code_length(number) do
      {:ok, gtin_type} ->
        {code, check_digit} = Enum.split(number, length(number) - 1)
        calculated_check_digit = code
          |> multiply_and_sum_array
          |> subtract_from_nearest_multiple_of_ten
        case calculated_check_digit == Enum.at(check_digit, 0) do
          true -> {:ok, gtin_type}
          _ -> {:error, "Invalid Code"}
        end
      {:error, error} -> {:error, error}
    end

  end

  @doc """
  Calculates the sum of the digits in a string and multiplied value based on index order

  Returns sum of values

  ## Examples

      iex> ExGtin.Validation.multiply_and_sum_array([6,2,9,1,0,4,1,5,0,0,2,1])
      57

  """
  @spec multiply_and_sum_array(list(number)) :: number
  def multiply_and_sum_array(numbers) do
    numbers
      |> Enum.reverse
      |> Stream.with_index
      |> Enum.reduce(0, fn({num, idx}, acc) ->
        acc + (num * mult_by_index_code(idx))
      end)
  end

  @doc """
  Calculates the difference of the highest rounded multiple of 10

  Returns the difference of the highest rounded multiple of 10

  ## Examples

      iex> ExGtin.Validation.subtract_from_nearest_multiple_of_ten(57)
      3

  """
  @spec subtract_from_nearest_multiple_of_ten(number) :: number
  def subtract_from_nearest_multiple_of_ten(number) do
    Integer.mod(10 - Integer.mod(number, 10), 10)
  end

  @doc """
  By index, returns the corresponding value to multiply
  the digit by

  Returns the value to multiply by

  ## Examples

      iex> ExGtin.Validation.mult_by_index_code(1)
      1

      iex> ExGtin.Validation.mult_by_index_code(2)
      3

  """
  @spec mult_by_index_code(number) :: number
  def mult_by_index_code(index) do
    case Integer.mod(index, 2) do
      0 -> 3
      _ -> 1
    end
  end

  @doc """
  Checks the code for the proper length as specified by the
  GTIN-8,12,13,14 specification

  Returns {:ok, gtin_type } | {:error | message}

  ## Examples

      iex> ExGtin.Validation.check_code_length([1,2,3,4,5,6,7,8])
      {:ok, "GTIN-8"}

      iex> ExGtin.Validation.check_code_length([1,2,3,4,5,6,7])
      {:error, "Invalid GTIN Code Length"}

  """
  @spec check_code_length(list(number)) :: {atom, string}
  def check_code_length(number) do
    case length(number) do
      8  -> {:ok, "GTIN-8"}
      12 -> {:ok, "GTIN-12"}
      13 -> {:ok, "GTIN-13"}
      14 -> {:ok, "GTIN-14"}
      _ -> {:error, "Invalid GTIN Code Length"}
    end
  end
end
