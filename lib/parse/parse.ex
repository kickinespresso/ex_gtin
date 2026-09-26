defmodule ExGtin.Parse do
  @moduledoc """
  Structured component extraction for GS1 codes.

  `parse/1` decomposes a valid GTIN-8/12/13/14 into the parts that the number
  alone can yield, so callers do not have to slice strings themselves:

    * `type` — derived from the code length (`"GTIN-8"`, `"GTIN-12"`, ...).
    * `digits` — the canonical digit string.
    * `indicator` — the leading packaging-level digit, set only for a GTIN-14;
      `nil` for every other type.
    * `gs1_prefix` — the leading three digits as a string.
    * `gs1_prefix_region` — the region for that prefix via
      `ExGtin.Validation.lookup_gs1_prefix/1`, or `nil` when the prefix is not
      in the table.
    * `check_digit` — the final digit as an integer.
    * `valid?` — whether the check digit matches the recomputed mod-10 value.

  Inputs may be a `String`, an integer, or a digit list, matching the rest of
  the `ExGtin` API.

  > #### No company/item split {: .info}
  >
  > `parse/1` deliberately does **not** split the body into a GS1 company
  > prefix and an item reference. The company-prefix length is assigned per
  > company and is not derivable from the number offline (it requires a GEPIR
  > lookup), so any offline split would be a guess.
  """
  @moduledoc since: "1.4.0"

  @typedoc """
  The decomposed parts of a GS1 code returned by `parse/1`.
  """
  @type parsed :: %{
          type: String.t(),
          digits: String.t(),
          indicator: nil | 0..9,
          gs1_prefix: String.t(),
          gs1_prefix_region: String.t() | nil,
          check_digit: 0..9,
          valid?: boolean
        }

  @doc """
  Decomposes a GTIN-8/12/13/14 into its structured components.

  Returns `{:ok, parsed}` for a well-formed code (correct length, all digits),
  where `parsed` is a `t:parsed/0` map. The `valid?` field reports whether the
  check digit matches; a tampered check digit yields `valid?: false` rather than
  an error. Returns an `{:error, _}` tuple when the input is not a valid code
  (wrong length or non-digit characters).

  ## Examples

      iex> ExGtin.Parse.parse("6291041500213")
      {:ok,
       %{
         type: "GTIN-13",
         digits: "6291041500213",
         indicator: nil,
         gs1_prefix: "629",
         gs1_prefix_region: "GS1 Emirates",
         check_digit: 3,
         valid?: true
       }}

      iex> ExGtin.Parse.parse("16291041500210")
      {:ok,
       %{
         type: "GTIN-14",
         digits: "16291041500210",
         indicator: 1,
         gs1_prefix: "162",
         gs1_prefix_region: nil,
         check_digit: 0,
         valid?: true
       }}

      iex> {:ok, %{valid?: false}} = ExGtin.Parse.parse("6291041500214")
      iex> :ok
      :ok

  """
  @doc since: "1.4.0"
  @spec parse(String.t() | integer | list(0..9)) :: {:ok, parsed} | {:error, String.t()}
  def parse(code) do
    with {:ok, digits} <- to_digits(code),
         {:ok, type} <- ExGtin.Validation.check_code_length(digits) do
      {:ok, build_parsed(digits, type)}
    end
  end

  # Coerces String / integer / digit-list input to a digit list, rejecting any
  # non-digit content uniformly.
  @spec to_digits(String.t() | integer | list(0..9)) ::
          {:ok, list(0..9)} | {:error, String.t()}
  defp to_digits(code) when is_bitstring(code) do
    code
    |> String.codepoints()
    |> Enum.reduce_while({:ok, []}, fn c, {:ok, acc} ->
      case Integer.parse(c) do
        {n, ""} -> {:cont, {:ok, acc ++ [n]}}
        _ -> {:halt, {:error, "Invalid Code"}}
      end
    end)
  end

  defp to_digits(code) when is_integer(code) and code >= 0,
    do: {:ok, Integer.digits(code)}

  defp to_digits(code) when is_list(code) do
    case Enum.all?(code, &(is_integer(&1) and &1 in 0..9)) do
      true -> {:ok, code}
      false -> {:error, "Invalid Code"}
    end
  end

  defp to_digits(_), do: {:error, "Invalid Code"}

  # Builds the parsed map from a validated-length digit list and its type.
  @spec build_parsed(list(0..9), String.t()) :: parsed
  defp build_parsed(digits, type) do
    %{
      type: type,
      digits: Enum.join(digits),
      indicator: indicator(digits, type),
      gs1_prefix: gs1_prefix_string(digits),
      gs1_prefix_region: gs1_prefix_region(digits),
      check_digit: List.last(digits),
      valid?: ExGtin.CheckDigit.valid?(digits)
    }
  end

  # The GTIN-14 indicator is the leading digit; all other types have none.
  @spec indicator(list(0..9), String.t()) :: nil | 0..9
  defp indicator(digits, "GTIN-14"), do: hd(digits)
  defp indicator(_digits, _type), do: nil

  # The leading three digits as a string.
  @spec gs1_prefix_string(list(0..9)) :: String.t()
  defp gs1_prefix_string(digits) do
    digits
    |> Enum.take(3)
    |> Enum.join()
  end

  # Looks up the region for the leading three digits, mapping an unknown prefix
  # to nil rather than an error so parse/1 stays honest about what is knowable.
  @spec gs1_prefix_region(list(0..9)) :: String.t() | nil
  defp gs1_prefix_region(digits) do
    prefix =
      digits
      |> Enum.take(3)
      |> Enum.join()
      |> String.to_integer()

    case ExGtin.Validation.lookup_gs1_prefix(prefix) do
      {:ok, region} -> region
      {:error, _} -> nil
    end
  end
end
