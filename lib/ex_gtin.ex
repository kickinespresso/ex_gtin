defmodule ExGtin do
  @moduledoc """
  Documentation for ExGtin. This library provides
  functionality for validating GTIN compliant codes.
  """
  @moduledoc since: "1.0.1"

  import ExGtin.Validation

  @type result :: {:ok, binary} | {:error, binary}

  @doc """
  Check for valid  GTIN-8, GTIN-12, GTIN-13, GTIN-14, GSIN, SSCC codes

  Returns `{:ok, "GTIN-#"}` or `{:error}`

  ## Examples

      iex> ExGtin.validate("6291041500213")
      {:ok, "GTIN-13"}

      iex> ExGtin.validate("6291041500214")
      {:error, "Invalid Code"}
  """
  @doc since: "0.4.0"
  @spec validate(String.t() | integer | list(number)) :: result
  def validate(number) do
    gtin_check_digit(number)
  end

  @doc """
  Converts a GTIN or ISBN to GTIN-14 format

  ## Examples

      iex> ExGtin.normalize("6291041500213")
      {:ok, "16291041500210"}
  """
  @doc since: "1.1.0"
  @spec normalize(binary | integer | list(number)) :: result
  def normalize(gtin) when is_list(gtin), do: normalize(Enum.join(gtin))

  def normalize(gtin) do
    with {:ok, type} <- do_gtin_check_digit(gtin),
         do: {:ok, normalize_gtin(gtin, type)}
  end

  defp do_gtin_check_digit(isbn) when is_bitstring(isbn) and byte_size(isbn) == 10 do
    cond do
      valid_isbn10?(isbn) -> {:ok, "ISBN-10"}
      # 10 well-formed ISBN-10 characters but a bad check digit -> not a valid code
      isbn10_shaped?(isbn) -> {:error, "Invalid Code"}
      # anything else (letters, separators, etc.) falls through and is handled
      # as a normal code, which raises on non-numeric input as before
      true -> gtin_check_digit(isbn)
    end
  end

  defp do_gtin_check_digit(gtin), do: gtin_check_digit(gtin)

  defp isbn10_shaped?(isbn), do: Regex.match?(~r/^[0-9]{9}[0-9Xx]$/, isbn)

  defp normalize_gtin(gtin, "GTIN-8") do
    digits = String.codepoints(gtin) |> Enum.map(&String.to_integer/1)
    {code, _} = Enum.split(digits, 7)
    "100000#{Enum.join(code)}#{generate_check_digit([1, 0, 0, 0, 0, 0] ++ code)}"
  end

  defp normalize_gtin(gtin, "ISBN-10") do
    code =
      gtin
      |> String.codepoints()
      |> Enum.take(9)
      |> Enum.map(&String.to_integer/1)

    "0978#{Enum.join(code)}#{generate_check_digit([9, 7, 8] ++ code)}"
  end

  defp normalize_gtin(gtin, "GTIN-12") do
    digits = String.codepoints(gtin) |> Enum.map(&String.to_integer/1)
    {code, _} = Enum.split(digits, 11)
    "10#{Enum.join(code)}#{generate_check_digit([1, 0] ++ code)}"
  end

  defp normalize_gtin(gtin, "GTIN-13") do
    digits = String.codepoints(gtin) |> Enum.map(&String.to_integer/1)
    {code, _} = Enum.split(digits, 12)
    "1#{Enum.join(code)}#{generate_check_digit([1] ++ code)}"
  end

  defp normalize_gtin(gtin, "GTIN-14"), do: gtin

  @doc """
  Check for valid  GTIN-8, GTIN-12, GTIN-13, GTIN-14, GSIN, SSCC codes

  Throws ArgumentError if an error occurs

  ## Examples

      iex> ExGtin.validate!("6291041500213")
      "GTIN-13"
  """
  @doc since: "1.2.0"
  @spec validate!(String.t() | integer | list(number)) :: String.t()
  def validate!(number) do
    case gtin_check_digit(number) do
      {:ok, result} -> result
      {:error, reason} -> raise ArgumentError, message: reason
    end
  end

  @doc """
  Generates valid  GTIN-8, GTIN-12, GTIN-13, GTIN-14, GSIN, SSCC codes

  Returns code with check digit

  ## Examples

      iex> ExGtin.generate("629104150021")
      {:ok, "6291041500213"}

      iex> ExGtin.generate("62921")
      {:error, "Invalid GTIN Code Length"}

  """
  @doc since: "0.4.0"
  @spec generate(String.t() | integer | list(number)) :: result
  def generate(number) do
    case generate_gtin_code(number) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Generates valid  GTIN-8, GTIN-12, GTIN-13, GTIN-14, GSIN, SSCC codes

  Throws Argument Exception if there was an error

  ## Examples

      iex> ExGtin.generate!("629104150021")
      "6291041500213"

      iex> ExGtin.generate!("62921")
      ** (ArgumentError) Invalid GTIN Code Length

  """
  @doc since: "1.2.0"
  @spec generate!(String.t() | integer | list(number)) :: binary()
  def generate!(number) do
    case generate_gtin_code(number) do
      {:ok, result} -> result
      {:error, reason} -> raise ArgumentError, message: reason
    end
  end

  @doc """
  Find the GS1 prefix country for a GTIN number

  Returns `{atom, String.t()}`

  ## Examples

      iex> ExGtin.gs1_prefix_country("53523235")
      {:ok, "GS1 Malta"}

      iex> ExGtin.gs1_prefix_country("6291041500214")
      {:ok, "GS1 Emirates"}

      iex> ExGtin.gs1_prefix_country("9541041500214")
      {:error, "No GS1 prefix found"}
  """
  @doc since: "0.1.0"
  @spec gs1_prefix_country(String.t() | integer | list(number)) :: {atom, String.t()}
  def gs1_prefix_country(number) do
    find_gs1_prefix_country(number)
  end
end
