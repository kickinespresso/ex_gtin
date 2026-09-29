defmodule ExGtin.Validation do
  @moduledoc """
  Documentation for ExGtin. This library provides
  functionality for validating GTIN compliant codes.
  """
  @moduledoc since: "1.0.0"

  @doc """
  Check for valid  GTIN-8, GTIN-12, GTIN-13, GTIN-14, GSIN, SSCC codes

  Returns `{atom, String.t()}`

  ## Examples

      iex> ExGtin.Validation.gtin_check_digit("6291041500213")
      {:ok, "GTIN-13"}

      iex> ExGtin.Validation.gtin_check_digit("6291041500214")
      {:error, "Invalid Code"}
  """
  @doc since: "1.0.0"
  @spec gtin_check_digit(String.t()) :: {atom, String.t()}
  def gtin_check_digit(number) when is_bitstring(number) do
    case string_to_digits(number) do
      {:ok, digits} -> gtin_check_digit(digits)
      {:error, error} -> {:error, error}
    end
  end

  @spec gtin_check_digit(integer) :: {atom, String.t()}
  def gtin_check_digit(number) when is_integer(number),
    do: gtin_check_digit(Integer.digits(number))

  @spec gtin_check_digit(float) :: {atom, String.t()}
  def gtin_check_digit(number) when is_float(number),
    do: {:error, "Invalid numeric input"}

  @spec gtin_check_digit(list(number)) :: {atom, String.t()}
  def gtin_check_digit(number) do
    case check_code_length(number) do
      {:ok, gtin_type} ->
        {code, check_digit} = Enum.split(number, length(number) - 1)

        calculated_check_digit =
          code
          |> multiply_and_sum_array
          |> subtract_from_nearest_multiple_of_ten

        case calculated_check_digit == Enum.at(check_digit, 0) do
          true -> {:ok, gtin_type}
          _ -> {:error, "Invalid Code"}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  # Safely converts a numeric string into a list of digits, returning
  # `{:error, "Invalid Code"}` when the string contains any non-digit
  # character (including whitespace) instead of raising from
  # `String.to_integer/1`. An empty string yields an empty digit list so the
  # downstream length check reports the existing "Invalid GTIN Code Length".
  @spec string_to_digits(String.t()) :: {:ok, list(0..9)} | {:error, String.t()}
  defp string_to_digits(string) do
    string
    |> String.codepoints()
    |> Enum.reduce_while({:ok, []}, fn char, {:ok, acc} ->
      case Integer.parse(char) do
        {digit, ""} when digit in 0..9 -> {:cont, {:ok, [digit | acc]}}
        _ -> {:halt, {:error, "Invalid Code"}}
      end
    end)
    |> case do
      {:ok, digits} -> {:ok, Enum.reverse(digits)}
      error -> error
    end
  end

  @doc """
  Validates an ISBN-10 string using the mod-11 check digit.
  The final character may be `X` (value 10).

  Returns `boolean`

  ## Examples

      iex> ExGtin.Validation.valid_isbn10?("155860832X")
      true

      iex> ExGtin.Validation.valid_isbn10?("1234567890")
      false
  """
  @doc since: "1.3.0"
  @spec valid_isbn10?(String.t()) :: boolean
  def valid_isbn10?(isbn) when is_bitstring(isbn) and byte_size(isbn) == 10 do
    chars = String.codepoints(isbn)
    {body, [check]} = Enum.split(chars, 9)

    with {:ok, body_digits} <- isbn10_digits(body),
         {:ok, check_value} <- isbn10_check_value(check) do
      sum =
        body_digits
        |> Enum.with_index()
        |> Enum.reduce(0, fn {d, i}, acc -> acc + (10 - i) * d end)

      rem(sum + check_value, 11) == 0
    else
      _ -> false
    end
  end

  def valid_isbn10?(_), do: false

  defp isbn10_digits(chars) do
    Enum.reduce_while(chars, {:ok, []}, fn c, {:ok, acc} ->
      case Integer.parse(c) do
        {n, ""} -> {:cont, {:ok, acc ++ [n]}}
        _ -> {:halt, :error}
      end
    end)
  end

  defp isbn10_check_value("X"), do: {:ok, 10}
  defp isbn10_check_value("x"), do: {:ok, 10}

  defp isbn10_check_value(c) do
    case Integer.parse(c) do
      {n, ""} -> {:ok, n}
      _ -> :error
    end
  end

  @doc """
  Generate valid  GTIN-8, GTIN-12, GTIN-13, GTIN-14, GSIN, SSCC codes

  Returns `{atom, String.t()}`

  ## Examples

      iex> ExGtin.Validation.generate_gtin_code("629104150021")
      {:ok, "6291041500213"}

      iex> ExGtin.Validation.generate_gtin_code("62921")
      {:error, "Invalid GTIN Code Length"}

  """
  @doc since: "1.0.0"
  @spec generate_gtin_code(String.t()) :: String.t() | {atom, String.t()}
  def generate_gtin_code(number) when is_bitstring(number) do
    case string_to_digits(number) do
      {:ok, digits} -> generate_gtin_code(digits)
      {:error, error} -> {:error, error}
    end
  end

  @spec generate_gtin_code(integer) :: String.t() | {atom, String.t()}
  def generate_gtin_code(number) when is_integer(number),
    do: generate_gtin_code(Integer.digits(number))

  @spec generate_gtin_code(float) :: {atom, String.t()}
  def generate_gtin_code(number) when is_float(number),
    do: {:error, "Invalid numeric input"}

  @spec generate_gtin_code(list(number)) :: String.t() | {atom, String.t()}
  def generate_gtin_code(number) do
    case generate_check_code_length(number) do
      {:ok, _} ->
        check_digit = generate_check_digit(number)
        result = Enum.join(number ++ [check_digit])
        {:ok, result}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Generate check digit  GTIN-8, GTIN-12, GTIN-13, GTIN-14, GSIN, SSCC codes

  Returns `number`

  ## Examples

      iex> ExGtin.Validation.generate_check_digit([6,2,9,1,0,4,1,5,0,0,2,1])
      3

  """
  @doc since: "1.0.0"
  @spec generate_check_digit(list(number)) :: number
  def generate_check_digit(number), do: ExGtin.CheckDigit.mod10(number)

  @doc """
  Calculates the sum of the digits in a string and multiplied value based on index order

  Returns `number`

  ## Examples

      iex> ExGtin.Validation.multiply_and_sum_array([6,2,9,1,0,4,1,5,0,0,2,1])
      57

  """
  @doc since: "1.0.0"
  @spec multiply_and_sum_array(list(number)) :: number
  def multiply_and_sum_array(numbers) do
    numbers
    |> Enum.reverse()
    |> Stream.with_index()
    |> Enum.reduce(0, fn {num, idx}, acc ->
      acc + num * mult_by_index_code(idx)
    end)
  end

  @doc """
  Calculates the difference of the highest rounded multiple of 10

  Returns `number`

  ## Examples

      iex> ExGtin.Validation.subtract_from_nearest_multiple_of_ten(57)
      3

  """
  @doc since: "1.0.0"
  @spec subtract_from_nearest_multiple_of_ten(number) :: number
  def subtract_from_nearest_multiple_of_ten(number), do: rem(10 - rem(number, 10), 10)

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
  @doc since: "1.0.0"
  @spec mult_by_index_code(number) :: number
  def mult_by_index_code(index) when rem(index, 2) == 1, do: 1
  def mult_by_index_code(_), do: 3

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
  @doc since: "1.0.0"
  @spec check_code_length([number]) :: {atom, String.t()}
  def check_code_length(number) do
    case length(number) do
      8 -> {:ok, "GTIN-8"}
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
  @doc since: "1.0.0"
  @spec generate_check_code_length(list(number)) :: {atom, String.t()}
  def generate_check_code_length(number), do: check_code_length(number ++ [1])

  @doc """
  Find the GS1 prefix country for a GTIN number

  Performs a *prefix-table* lookup on the leading digits of the input against
  the GTIN-13 country-prefix table.

  > #### GTIN-8 lookups are deprecated {: .warning}
  >
  > For an 8-digit (GTIN-8) input this does **not** implement true GS1-8 prefix
  > semantics (the `960..969` "Global Office GTIN-8" range); it simply looks the
  > leading three digits up in the same GTIN-13 table, which can return a
  > **misleading** Member Organisation for a GTIN-8. Passing a GTIN-8 to this
  > function is deprecated and may change (or start returning an error) in a
  > future release once real GS1-8 prefix support lands. GTIN-12/13/14 lookups
  > are unaffected.

  Prefer the public facade `ExGtin.gs1_prefix_country/1` over calling this
  internal `ExGtin.Validation` function directly.

  Returns `{atom, String.t()}`

  ## Examples

      iex> ExGtin.Validation.find_gs1_prefix_country("6291041500214")
      {:ok, "GS1 Emirates"}

      iex> ExGtin.Validation.find_gs1_prefix_country("9541041500214")
      {:error, "No GS1 prefix found"}
  """
  @doc since: "1.0.0"
  @doc deprecated:
         "Passing a GTIN-8 to find_gs1_prefix_country/1 uses GTIN-13 prefix semantics and may be misleading; prefer ExGtin.gs1_prefix_country/1 for GTIN-12/13/14."
  @spec find_gs1_prefix_country(String.t()) :: {atom, String.t()}
  def find_gs1_prefix_country(number) when is_bitstring(number) do
    case string_to_digits(number) do
      {:ok, digits} -> find_gs1_prefix_country(digits)
      {:error, error} -> {:error, error}
    end
  end

  @spec find_gs1_prefix_country(integer) :: {atom, String.t()}
  def find_gs1_prefix_country(number) when is_integer(number),
    do: find_gs1_prefix_country(Integer.digits(number))

  @spec find_gs1_prefix_country(float) :: {atom, String.t()}
  def find_gs1_prefix_country(number) when is_float(number),
    do: {:error, "Invalid numeric input"}

  @spec find_gs1_prefix_country(list(number)) :: {atom, String.t()}
  def find_gs1_prefix_country(number) do
    case check_code_length(number) do
      {:ok, gtin_type} ->
        normalized =
          case gtin_type do
            "GTIN-12" -> [0] ++ number
            "GTIN-14" -> Enum.drop(number, 1)
            _ -> number
          end

        {prefix, _code} = Enum.split(normalized, 3)

        prefix
        |> Enum.join()
        |> String.to_integer()
        |> lookup_gs1_prefix

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Looks up the GS1 prefix in a table
  GS1 Reference https://www.gs1.org/company-prefix

  Returns {atom, String.t()}

  """
  # GS1 prefix table — verified against the official GS1 Company Prefix
  # allocation list as of 2026-09-26.
  # Source: https://www.gs1.org/standards/id-keys/company-prefix
  # Cross-referenced with the maintained public summary at
  # https://en.wikipedia.org/wiki/List_of_GS1_country_codes (source: GS1
  # Company Prefix). Note: GS1 prefixes identify the issuing Member
  # Organisation, not a product's country of origin. Lookups are performed on
  # the leading 3 digits, so allocations finer than 3 digits (e.g. the
  # 960–969 GTIN-8 sub-ranges) are represented at 3-digit granularity.
  #
  # Ordered list of {range, name} tuples. Lookup traverses top-to-bottom and
  # returns the first entry whose range contains the number, replicating the
  # top-to-bottom clause semantics of the previous case statement. Refreshing
  # the table is now a data edit here rather than a code change.
  @gs1_prefixes [
    {001..019, "GS1 US"},
    {030..039, "GS1 US"},
    {050..059, "GS1 US"},
    {060..099, "GS1 US"},
    {100..139, "GS1 US"},
    {020..029,
     "Used to issue restricted circulation numbers within a geographic region (MO defined)"},
    {040..049, "Used to issue GS1 restricted circulation numbers within a company"},
    {200..299,
     "Used to issue GS1 restricted circulation number within a geographic region (MO defined)"},
    {300..379, "GS1 France"},
    {380..380, "GS1 Bulgaria"},
    {381..381, "GS1 Kosovo"},
    {383..383, "GS1 Slovenija"},
    {385..385, "GS1 Croatia"},
    {387..387, "GS1 BIH (Bosnia-Herzegovina)"},
    {389..389, "GS1 Montenegro"},
    {400..440, "GS1 Germany"},
    {450..459, "GS1 Japan"},
    {490..499, "GS1 Japan"},
    {460..469, "GS1 Russia"},
    {470..470, "GS1 Kyrgyzstan"},
    {471..471, "GS1 Taiwan"},
    {474..474, "GS1 Estonia"},
    {475..475, "GS1 Latvia"},
    {476..476, "GS1 Azerbaijan"},
    {477..477, "GS1 Lithuania"},
    {478..478, "GS1 Uzbekistan"},
    {479..479, "GS1 Sri Lanka"},
    {480..480, "GS1 Philippines"},
    {481..481, "GS1 Belarus"},
    {482..482, "GS1 Ukraine"},
    {483..483, "GS1 Turkmenistan"},
    {484..484, "GS1 Moldova"},
    {485..485, "GS1 Armenia"},
    {486..486, "GS1 Georgia"},
    {487..487, "GS1 Kazakstan"},
    {488..488, "GS1 Tajikistan"},
    {489..489, "GS1 Hong Kong"},
    {500..509, "GS1 UK"},
    {520..521, "GS1 Association Greece"},
    {528..528, "GS1 Lebanon"},
    {529..529, "GS1 Cyprus"},
    {530..530, "GS1 Albania"},
    {531..531, "GS1 North Macedonia"},
    {535..535, "GS1 Malta"},
    {539..539, "GS1 Ireland"},
    {540..549, "GS1 Belgium & Luxembourg"},
    {560..560, "GS1 Portugal"},
    {569..569, "GS1 Iceland"},
    {570..579, "GS1 Denmark"},
    {590..590, "GS1 Poland"},
    {594..594, "GS1 Romania"},
    {599..599, "GS1 Hungary"},
    {600..601, "GS1 South Africa"},
    {603..603, "GS1 Ghana"},
    {604..604, "GS1 Senegal"},
    {605..605, "GS1 Uganda"},
    {606..606, "GS1 Angola"},
    {607..607, "GS1 Oman"},
    {608..608, "GS1 Bahrain"},
    {609..609, "GS1 Mauritius"},
    {611..611, "GS1 Morocco"},
    {612..612, "GS1 Somalia"},
    {613..613, "GS1 Algeria"},
    {615..615, "GS1 Nigeria"},
    {616..616, "GS1 Kenya"},
    {617..617, "GS1 Cameroon"},
    {618..618, "GS1 Ivory Coast"},
    {619..619, "GS1 Tunisia"},
    {620..620, "GS1 Tanzania"},
    {621..621, "GS1 Syria"},
    {622..622, "GS1 Egypt"},
    # NOTE: Per GS1, prefix 623 was reassigned from Brunei to "Managed by GS1
    # Global Office for future MO" in May 2021. The historical "GS1 Brunei"
    # value is retained to preserve existing behavior; revisit if a definitive
    # replacement label is required.
    {623..623, "GS1 Brunei"},
    {624..624, "GS1 Libya"},
    {625..625, "GS1 Jordan"},
    {626..626, "GS1 Iran"},
    {627..627, "GS1 Kuwait"},
    {628..628, "GS1 Saudi Arabia"},
    {629..629, "GS1 Emirates"},
    {630..630, "GS1 Qatar"},
    {631..631, "GS1 Namibia"},
    {632..632, "GS1 Rwanda"},
    {640..649, "GS1 Finland"},
    {680..681, "GS1 China"},
    {690..699, "GS1 China"},
    {700..709, "GS1 Norway"},
    {729..729, "GS1 Israel"},
    {730..739, "GS1 Sweden"},
    {740..740, "GS1 Guatemala"},
    {741..741, "GS1 El Salvador"},
    {742..742, "GS1 Honduras"},
    {743..743, "GS1 Nicaragua"},
    {744..744, "GS1 Costa Rica"},
    {745..745, "GS1 Panama"},
    {746..746, "GS1 Republica Dominicana"},
    {750..750, "GS1 Mexico"},
    {754..755, "GS1 Canada"},
    {759..759, "GS1 Venezuela"},
    {760..769, "GS1 Schweiz, Suisse, Svizzera"},
    {770..771, "GS1 Colombia"},
    {773..773, "GS1 Uruguay"},
    {775..775, "GS1 Peru"},
    {777..777, "GS1 Bolivia"},
    {778..779, "GS1 Argentina"},
    {780..780, "GS1 Chile"},
    {784..784, "GS1 Paraguay"},
    {786..786, "GS1 Ecuador"},
    {789..790, "GS1 Brasil"},
    {800..839, "GS1 Italy"},
    {840..849, "GS1 Spain"},
    {850..850, "GS1 Cuba"},
    {858..858, "GS1 Slovakia"},
    {859..859, "GS1 Czech"},
    {860..860, "GS1 Serbia"},
    {865..865, "GS1 Mongolia"},
    {867..867, "GS1 North Korea"},
    {868..869, "GS1 Turkey"},
    {870..879, "GS1 Netherlands"},
    {880..881, "GS1 South Korea"},
    {883..883, "GS1 Myanmar"},
    {884..884, "GS1 Cambodia"},
    {885..885, "GS1 Thailand"},
    {887..887, "GS1 Laos"},
    {888..888, "GS1 Singapore"},
    {890..890, "GS1 India"},
    {893..893, "GS1 Vietnam"},
    {894..894, "GS1 Bangladesh"},
    {896..896, "GS1 Pakistan"},
    {899..899, "GS1 Indonesia"},
    {900..919, "GS1 Austria"},
    {930..939, "GS1 Australia"},
    {940..949, "GS1 New Zealand"},
    {950..950, "GS1 Global Office"},
    {951..951,
     "Used to issue General Manager Numbers for the EPC General Identifier (GID) scheme as defined by the EPC Tag Data Standard*"},
    {952..952, "Used for demonstrations and examples of the GS1 system"},
    {955..955, "GS1 Malaysia"},
    {958..958, "GS1 Macau"},
    {960..969, "Global Office (GTIN-8s)*"},
    {977..977, "Serial publications (ISSN)"},
    {978..979, "Bookland (ISBN)"},
    {980..980, "Refund receipts"},
    {981..984, "GS1 coupon identification for common currency areas"},
    {990..999, "GS1 coupon identification"}
  ]

  @doc since: "1.0.0"
  @spec lookup_gs1_prefix(integer) :: {atom, String.t()}
  def lookup_gs1_prefix(number) do
    case Enum.find(@gs1_prefixes, fn {range, _name} -> number in range end) do
      {_range, name} -> {:ok, name}
      nil -> {:error, "No GS1 prefix found"}
    end
  end
end
