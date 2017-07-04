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
      {:ok}

      iex> ExGtin.check_gtin("6291041500214")
      {:error}
  """
  @spec check_gtin(string | list(number)) :: {atom}
  def check_gtin(number) do
    gtin_check_digit(number)
  end

end
