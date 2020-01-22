defmodule ExGtin do
  @moduledoc """
  Documentation for ExGtin. This library provides
  functionality for validating GTIN compliant codes.
  """

  import ExGtin.Validation

  @doc """
  Check for valid  GTIN-8, GTIN-12, GTIN-13, GTIN-14, GSIN, SSCC codes

  Returns `{:ok, "GTIN-#"}` or `{:error}`

  ## Examples

      iex> ExGtin.validate("6291041500213")
      {:ok, "GTIN-13"}

      iex> ExGtin.validate("6291041500214")
      {:error, "Invalid Code"}
  """
  @since "0.4.0"
  @spec validate(String.t() | list(number)) :: {atom, String.t()}
  def validate(number) do
    gtin_check_digit(number)
  end

  @doc """
  Check for valid  GTIN-8, GTIN-12, GTIN-13, GTIN-14, GSIN, SSCC codes

  Throws ArgumentError if an error occurs

  ## Examples

      iex> ExGtin.validate!("6291041500213")
      "GTIN-13"
  """
  @since "1.0.0"
  @spec validate!(String.t() | list(number)) :: {atom, String.t()}
  def validate!(number) do
     case gtin_check_digit(number) do
      {:ok, result} -> result
      {:error, reason} -> raise ArgumentError, message: reason
    end
  end

  @doc """
  Check for valid  GTIN-8, GTIN-12, GTIN-13, GTIN-14, GSIN, SSCC codes

  Returns `{:ok}` or `{:error}`

  ## Examples

      iex> ExGtin.check_gtin("6291041500213")
      {:ok, "GTIN-13"}

      iex> ExGtin.check_gtin("6291041500214")
      {:error, "Invalid Code"}
  """
  @deprecated "Use validate/1 instead. Will be removed in version 1.0.1"
  @since "0.1.0"
  @spec check_gtin(String.t() | list(number)) :: {atom, String.t()}
  def check_gtin(number) do
    gtin_check_digit(number)
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
  @since "0.4.0"
  @spec generate(String.t() | list(number)) :: number | {atom, String.t()}
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

      iex> ExGtin.generate("62921")
      {:error, "Invalid GTIN Code Length"}

  """
  @since "1.0.0"
  @spec generate!(String.t() | list(number)) :: number | {atom, String.t()}
  def generate!(number) do
    case generate_gtin_code(number) do
      {:ok, result} -> result
      {:error, reason} -> raise ArgumentError, message: reason
    end
  end

  @doc """
  Generates valid  GTIN-8, GTIN-12, GTIN-13, GTIN-14, GSIN, SSCC codes

  Returns code with check digit

  ## Examples

      iex> ExGtin.generate_gtin("629104150021")
      "6291041500213"

      iex> ExGtin.generate_gtin("62921")
      {:error, "Invalid GTIN Code Length"}

  """
  @deprecated "Use generate/1 instead. Will be removed in version 1.0.1"
  @since "0.1.0"
  @spec generate_gtin(String.t() | list(number)) :: number | {atom, String.t()}
  def generate_gtin(number) do
    case generate_gtin_code(number) do
      {:ok, result} -> result
      {:error, reason} ->  {:error, reason}
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
  @since "0.1.0"
  @spec gs1_prefix_country(String.t() | list(number)) :: {atom, String.t()}
  def gs1_prefix_country(number) do
    find_gs1_prefix_country(number)
  end

end
