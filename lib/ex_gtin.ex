defmodule ExGtin do
  @moduledoc """
  Documentation for ExGtin. This library provides
  functionality for validating GTIN compliant codes.
  """

  import ExGtin.Validation

  @doc """
  Check for valid  GTIN-8, GTIN-12, GTIN-13, GTIN-14, GSIN, SSCC codes

  Returns `{:ok}` or `{:error}`

  ## Examples

      iex> ExGtin.check_gtin("6291041500213")
      {:ok, "GTIN-13"}

      iex> ExGtin.check_gtin("6291041500214")
      {:error, "Invalid Code"}
  """
  @spec check_gtin(String.t() | list(number)) :: {atom, String.t()}
  def check_gtin(number) do
    gtin_check_digit(number)
  end

  @doc """
  Generates valid  GTIN-8, GTIN-12, GTIN-13, GTIN-14, GSIN, SSCC codes

  Returns code with check digit

  ## Examples

      iex> ExGtin.generate_gtin("629104150021")
      "6291041500213"

  """
  @spec generate_gtin(String.t() | list(number)) :: number | {atom, String.t()}
  def generate_gtin(number) do
    generate_gtin_code(number)
  end

end
