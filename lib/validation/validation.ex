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

 @doc """
  Find the GS1 prefix country for a GTIN number

  Returns `{atom, String.t()}`

  ## Examples

      iex> ExGtin.Validation.find_gs1_prefix_country("53523235")
      {:ok, "GS1 Malta"}

      iex> ExGtin.Validation.find_gs1_prefix_country("6291041500214")
      {:ok, "GS1 Emirates"}

      iex> ExGtin.Validation.find_gs1_prefix_country("9541041500214")
      {:error, "No GS1 prefix found"}
  """
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
    case check_code_length(number) do
      {:ok, _gtin_type} ->
        {prefix, _code} = Enum.split(number, 3)
        prefix
          |> Enum.join
          |> String.to_integer
          |> lookup_gs1_prefix
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Looks up the GS1 prefix in a table
  GS1 Reference https://www.gs1.org/company-prefix

  Returns {atom, String.t()}

  """
  @spec lookup_gs1_prefix(integer) :: {atom, String.t()}
  def lookup_gs1_prefix(number) do
    case number do
      x when x in 001..019 -> {:ok, "GS1 US"}
      x when x in 030..039 -> {:ok, "GS1 US"}
      x when x in 050..059 -> {:ok, "GS1 US"}
      x when x in 060..139 -> {:ok, "GS1 US"}
      x when x == 535 -> {:ok, "GS1 Malta"}
      x when x in 020..029 -> {:ok, "Used to issue restricted circulation numbers within a geographic region (MO defined)   "}
      x when x in 040..049 -> {:ok, "Used to issue GS1 restricted circulation numbers within a company"}
      x when x in 200..299 -> {:ok, "Used to issue GS1 restricted circulation number within a geographic region (MO defined)"}
      x when x in 300..379 -> {:ok, "GS1 France"}
      x when x == 380 -> {:ok, "GS1 Bulgaria"}
      x when x == 383 -> {:ok, "GS1 Slovenija"}
      x when x == 385 -> {:ok, "GS1 Croatia"}
      x when x == 387 -> {:ok, "GS1 BIH (Bosnia-Herzegovina)"}
      x when x == 389 -> {:ok, "GS1 Montenegro"}
      x when x in 400..440 -> {:ok, "GS1 Germany"}
      x when x in 450..459  -> {:ok, "GS1 Japan"}
      x when x in 490..499 -> {:ok, "GS1 Japan"}
      x when x in 460..469 -> {:ok, "GS1 Russia"}
      x when x == 470 -> {:ok, "GS1 Kyrgyzstan"}
      x when x == 471 -> {:ok, "GS1 Taiwan"}
      x when x == 474 -> {:ok, "GS1 Estonia"}
      x when x == 475 -> {:ok, "GS1 Latvia"}
      x when x == 476 -> {:ok, "GS1 Azerbaijan"}
      x when x == 477 -> {:ok, "GS1 Lithuania"}
      x when x == 478 -> {:ok, "GS1 Uzbekistan"}
      x when x == 479 -> {:ok, "GS1 Sri Lanka"}
      x when x == 480 -> {:ok, "GS1 Philippines"}
      x when x == 481 -> {:ok, "GS1 Belarus"}
      x when x == 482 -> {:ok, "GS1 Ukraine"}
      x when x == 483 -> {:ok, "GS1 Turkmenistan"}
      x when x == 484 -> {:ok, "GS1 Moldova"}
      x when x == 485 -> {:ok, "GS1 Armenia"}
      x when x == 486 -> {:ok, "GS1 Georgia"}
      x when x == 487 -> {:ok, "GS1 Kazakstan"}
      x when x == 488 -> {:ok, "GS1 Tajikistan"}
      x when x == 489 -> {:ok, "GS1 Hong Kong"}
      x when x in 500..509 -> {:ok, "GS1 UK"}
      x when x in 520..521 -> {:ok, "GS1 Association Greece"}
      x when x == 528 -> {:ok, "GS1 Lebanon"}
      x when x == 529 -> {:ok, "GS1 Cyprus"}
      x when x == 530 -> {:ok, "GS1 Albania"}
      x when x == 531 -> {:ok, "GS1 Macedonia"}
      x when x == 535 -> {:ok, "GS1 Malta"}
      x when x == 539 -> {:ok, "GS1 Ireland"}
      x when x in 540..549 -> {:ok, "GS1 Belgium & Luxembourg"}
      x when x == 560 -> {:ok, "GS1 Portugal"}
      x when x == 569 -> {:ok, "GS1 Iceland"}
      x when x in 570..579 -> {:ok, "GS1 Denmark"}
      x when x == 590 -> {:ok, "GS1 Poland"}
      x when x == 594 -> {:ok, "GS1 Romania"}
      x when x == 599 -> {:ok, "GS1 Hungary"}
      x when x in 600..601 -> {:ok, "GS1 South Africa"}
      x when x == 603 -> {:ok, "GS1 Ghana"}
      x when x == 604 -> {:ok, "GS1 Senegal"}
      x when x == 608 -> {:ok, "GS1 Bahrain"}
      x when x == 609 -> {:ok, "GS1 Mauritius"}
      x when x == 611 -> {:ok, "GS1 Morocco"}
      x when x == 613 -> {:ok, "GS1 Algeria"}
      x when x == 615 -> {:ok, "GS1 Nigeria"}
      x when x == 616 -> {:ok, "GS1 Kenya"}
      x when x == 618 -> {:ok, "GS1 Ivory Coast"}
      x when x == 619 -> {:ok, "GS1 Tunisia"}
      x when x == 620 -> {:ok, "GS1 Tanzania"}
      x when x == 621 -> {:ok, "GS1 Syria"}
      x when x == 622 -> {:ok, "GS1 Egypt"}
      x when x == 623 -> {:ok, "GS1 Brunei"}
      x when x == 624 -> {:ok, "GS1 Libya"}
      x when x == 625 -> {:ok, "GS1 Jordan"}
      x when x == 626 -> {:ok, "GS1 Iran"}
      x when x == 627 -> {:ok, "GS1 Kuwait"}
      x when x == 628 -> {:ok, "GS1 Saudi Arabia"}
      x when x == 629 -> {:ok, "GS1 Emirates"}
      x when x in 640..649 -> {:ok, "GS1 Finland"}
      x when x in 690..699 -> {:ok, "GS1 China"}
      x when x in 700..709 -> {:ok, "GS1 Norway"}
      x when x == 729 -> {:ok, "GS1 Israel"}
      x when x in 730..739 -> {:ok, "GS1 Sweden"}
      x when x == 740 -> {:ok, "GS1 Guatemala"}
      x when x == 741 -> {:ok, "GS1 El Salvador"}
      x when x == 742 -> {:ok, "GS1 Honduras"}
      x when x == 743 -> {:ok, "GS1 Nicaragua"}
      x when x == 744 -> {:ok, "GS1 Costa Rica"}
      x when x == 745 -> {:ok, "GS1 Panama"}
      x when x == 746 -> {:ok, "GS1 Republica Dominicana"}
      x when x == 750 -> {:ok, "GS1 Mexico"}
      x when x in 754..755 -> {:ok, "GS1 Canada"}
      x when x == 759 -> {:ok, "GS1 Venezuela"}
      x when x in 760..769 -> {:ok, "GS1 Schweiz, Suisse, Svizzera"}
      x when x in 770..771 -> {:ok, "GS1 Colombia"}
      x when x == 773 -> {:ok, "GS1 Uruguay"}
      x when x == 775 -> {:ok, "GS1 Peru"}
      x when x == 777 -> {:ok, "GS1 Bolivia"}
      x when x in 778..779 -> {:ok, "GS1 Argentina"}
      x when x == 780 -> {:ok, "GS1 Chile"}
      x when x == 784 -> {:ok, "GS1 Paraguay"}
      x when x == 786 -> {:ok, "GS1 Ecuador"}
      x when x in 789..790 -> {:ok, "GS1 Brasil  "}
      x when x in 800..839 -> {:ok, "GS1 Italy  "}
      x when x in 840..849 -> {:ok, "GS1 Spain  "}
      x when x == 850 -> {:ok, "GS1 Cuba"}
      x when x == 858 -> {:ok, "GS1 Slovakia"}
      x when x == 859 -> {:ok, "GS1 Czech"}
      x when x == 860 -> {:ok, "GS1 Serbia"}
      x when x == 865 -> {:ok, "GS1 Mongolia"}
      x when x == 867 -> {:ok, "GS1 North Korea"}
      x when x in 868..869 -> {:ok, "GS1 Turkey"}
      x when x in 870..879 -> {:ok, "GS1 Netherlands"}
      x when x == 880 -> {:ok, "GS1 South Korea"}
      x when x == 884 -> {:ok, "GS1 Cambodia"}
      x when x == 885 -> {:ok, "GS1 Thailand"}
      x when x == 888 -> {:ok, "GS1 Singapore"}
      x when x == 890 -> {:ok, "GS1 India"}
      x when x == 893 -> {:ok, "GS1 Vietnam"}
      x when x == 896 -> {:ok, "GS1 Pakistan"}
      x when x == 899 -> {:ok, "GS1 Indonesia"}
      x when x in 900..919 -> {:ok, "GS1 Austria"}
      x when x in 930..939 -> {:ok, "GS1 Australia"}
      x when x in 940..949 -> {:ok, "GS1 New Zealand"}
      x when x == 950 -> {:ok, "GS1 Global Office"}
      x when x == 951 -> {:ok, "Used to issue General Manager Numbers for the EPC General Identifier (GID) scheme as defined by the EPC Tag Data Standard*"}
      x when x == 955 -> {:ok, "GS1 Malaysia"}
      x when x == 958 -> {:ok, "GS1 Macau"}
      x when x in 960..969 -> {:ok, "Global Office (GTIN-8s)*"}
      x when x == 977 -> {:ok, "Serial publications (ISSN)"}
      x when x in 978..979 -> {:ok, "Bookland (ISBN)"}
      x when x == 980 -> {:ok, "Refund receipts"}
      x when x in 981..984 -> {:ok, "GS1 coupon identification for common currency areas"}
      x when x == 99 -> {:ok, "GS1 coupon identification"}
      _ -> {:error, "No GS1 prefix found"}
    end
  end
end
