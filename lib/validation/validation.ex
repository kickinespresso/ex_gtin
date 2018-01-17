defmodule ExGtin.Validation do
  @moduledoc """
  Documentation for ExGtin. This library provides
  functionality for validating GTIN compliant codes.
  """

  @doc """
  Check for valid  GTIN-8, GTIN-12, GTIN-13, GTIN-14, GSIN, SSCC codes

  Returns `{atom, String.t()}`

  ## Examples

      iex> ExGtin.Validation.gtin_check_digit("6291041500213")
      {:ok, "GTIN-13"}

      iex> ExGtin.Validation.gtin_check_digit("6291041500214")
      {:error, "Invalid Code"}
  """
  @spec gtin_check_digit(String.t()) :: {atom, String.t()}
  def gtin_check_digit(number) when is_bitstring(number) do
    number
      |> String.codepoints
      |> Enum.map(fn(x) -> String.to_integer(x) end)
      |> gtin_check_digit
  end

  @spec gtin_check_digit(number) :: {atom, String.t()}
  def gtin_check_digit(number) when is_number(number), do: gtin_check_digit(Integer.digits(number))

  @spec gtin_check_digit(list(number)) :: {atom, String.t()}
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
  Generate valid  GTIN-8, GTIN-12, GTIN-13, GTIN-14, GSIN, SSCC codes

  Returns `{atom, String.t()}`

  ## Examples

      iex> ExGtin.Validation.generate_gtin_code("629104150021")
      "6291041500213"

      iex> ExGtin.Validation.generate_gtin_code("62921")
      {:error, "Invalid GTIN Code Length"}

  """
  @spec generate_gtin_code(String.t()) :: String.t() | {atom, String.t()}
  def generate_gtin_code(number) when is_bitstring(number) do
    number
      |> String.codepoints
      |> Enum.map(fn(x) -> String.to_integer(x) end)
      |> generate_gtin_code
  end

  @spec generate_gtin_code(number) :: String.t() | {atom, String.t()}
  def generate_gtin_code(number) when is_number(number), do: generate_gtin_code(Integer.digits(number))

  @spec generate_gtin_code(list(number)) :: String.t() | {atom, String.t()}
  def generate_gtin_code(number) do
    case generate_check_code_length(number) do
      {:ok, _} ->
        check_digit = generate_check_digit(number)
        number
         |> Enum.concat([check_digit])
         |> Enum.join
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Generate check digit  GTIN-8, GTIN-12, GTIN-13, GTIN-14, GSIN, SSCC codes

  Returns `number`

  ## Examples

      iex> ExGtin.Validation.generate_check_digit([6,2,9,1,0,4,1,5,0,0,2,1])
      3

  """
  @spec generate_check_digit(list(number)) :: number
  def generate_check_digit(number) do
    number
      |> multiply_and_sum_array
      |> subtract_from_nearest_multiple_of_ten
  end

  @doc """
  Calculates the sum of the digits in a string and multiplied value based on index order

  Returns `number`

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

  Returns `number`

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

  Returns `number`

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

  Returns {atom, String.t()}

  ## Examples

      iex> ExGtin.Validation.check_code_length([1,2,3,4,5,6,7,8])
      {:ok, "GTIN-8"}

      iex> ExGtin.Validation.check_code_length([1,2,3,4,5,6,7])
      {:error, "Invalid GTIN Code Length"}

  """
  @spec check_code_length(list(number)) :: {atom, String.t()}
  def check_code_length(number) do
    case length(number) do
      8  -> {:ok, "GTIN-8"}
      12 -> {:ok, "GTIN-12"}
      13 -> {:ok, "GTIN-13"}
      14 -> {:ok, "GTIN-14"}
      _ -> {:error, "Invalid GTIN Code Length"}
    end
  end

  @doc """
  When generating the code, checks the code for
  the proper length as specified by the GTIN-8,12,13,14 specification.
  The code should be -1 the length of the GTIN code as the check digit
  will be added later

  Returns {atom, String.t()}

  ## Examples

      iex> ExGtin.Validation.generate_check_code_length([1,2,3,4,5,6,7])
      {:ok, "GTIN-8"}

      iex> ExGtin.Validation.generate_check_code_length([1,2,3,4,5,6])
      {:error, "Invalid GTIN Code Length"}

  """
  @spec generate_check_code_length(list(number)) :: {atom, String.t()}
  def generate_check_code_length(number), do: check_code_length(number ++ [1])


  @spec find_gs1_prefix_country(String.t()) :: {atom, String.t()}
  def find_gs1_prefix_country(number) when is_bitstring(number) do
    number
      |> String.codepoints
      |> Enum.map(fn(x) -> String.to_integer(x) end)
      |> find_gs1_prefix_country
  end

  @spec find_gs1_prefix_country(number) :: {atom, String.t()}
  def find_gs1_prefix_country(number) when is_number(number), do: find_gs1_prefix_country(Integer.digits(number))

  @spec find_gs1_prefix_country(list(number)) :: {atom, String.t()}
  def find_gs1_prefix_country(number) do
    IO.puts "here"
    case check_code_length(number) do
      {:ok, gtin_type} ->
        {prefix, code} = Enum.split(number, 3)
        prefix
          |> Enum.join
          |> String.to_integer
          |> lookup_gs1_prefix
        # calculated_check_digit = code
        #   |> multiply_and_sum_array
        #   |> subtract_from_nearest_multiple_of_ten
        # case calculated_check_digit == Enum.at(check_digit, 0) do
        #   true -> {:ok, gtin_type}
        #   _ -> {:error, "Invalid Code"}
        # end
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Looks up the GS1 prefix in a table
  GS1 Reference https://www.gs1.org/company-prefix
  """
  @spec lookup_gs1_prefix(integer) :: {atom, String.t()}
  def lookup_gs1_prefix(number) do
    case number do
      x when x in 001..019 -> {:ok, "GS1 US"}
      x when x in 030..039 -> {:ok, "GS1 US"}
      x when x in 050..059 -> {:ok, "GS1 US"}
      x when x in 060..139 -> {:ok, "GS1 US"}
      x when x == 535 -> {:ok, "GS1 Malta"}
      _ -> {:error, "No GS1 prefix found"}
    end

  end
end
