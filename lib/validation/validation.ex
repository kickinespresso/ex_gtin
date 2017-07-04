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
      {:ok}

      iex> ExGtin.Validation.gtin_check_digit("6291041500214")
      {:error}
  """
  @spec gtin_check_digit(string) :: {atom}
  def gtin_check_digit(number) when is_bitstring(number) do
    number
      |> String.codepoints
      |> Enum.map(fn(x) -> String.to_integer(x) end)
      |> gtin_check_digit
  end

  @spec gtin_check_digit(number) :: {atom}
  def gtin_check_digit(number) when is_number(number), do: gtin_check_digit(Integer.digits(number))

  @spec gtin_check_digit(list(number)) :: {atom}
  def gtin_check_digit(number) do
    {code, check_digit} = Enum.split(number, length(number) - 1)
    calculated_check_digit = code
      |> multiply_and_sum_array
      |> subtract_from_nearest_multiple_of_ten

    case calculated_check_digit == Enum.at(check_digit, 0) do
      true -> {:ok}
      _ -> {:error}
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

  def mult_by_index_code(index) do
    case Integer.mod(index, 2) do
      0 -> 3
      _ -> 1
    end
  end

end
