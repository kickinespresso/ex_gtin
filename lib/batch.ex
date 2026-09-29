defmodule ExGtin.Batch do
  @moduledoc """
  Batch helpers for validating many GTIN inputs in one call.

  These are thin, order-preserving wrappers over `ExGtin.validate/1` for the
  common case of checking a list of codes at once. Neither function raises on an
  individual item: every input flows through `ExGtin.validate/1`, whose result
  (`{:ok, binary} | {:error, binary}`) is captured per element, so one bad code
  never aborts the batch.

    * `validate_all/1` keeps every input paired with its own result, in the
      original order — useful when the caller needs to report why a specific
      code failed.
    * `partition/1` splits the inputs into `valid` and `invalid` buckets,
      preserving order within each bucket — useful when the caller only needs
      the two groups.

  An empty input list yields an empty result (`validate_all/1`) or empty buckets
  (`partition/1`).
  """
  @moduledoc since: "1.4.0"

  @doc """
  Validates a list of codes, pairing each input with its `ExGtin.validate/1`
  result.

  Maps each element of `codes` to a `{input, result}` tuple, where `result` is
  the `{:ok, binary} | {:error, binary}` value returned by `ExGtin.validate/1`.
  List order is preserved and individual items never raise. An empty list
  returns an empty list.

  ## Examples

      iex> ExGtin.Batch.validate_all(["6291041500213", "6291041500214"])
      [
        {"6291041500213", {:ok, "GTIN-13"}},
        {"6291041500214", {:error, "Invalid Code"}}
      ]

      iex> ExGtin.Batch.validate_all([])
      []

  """
  @doc since: "1.4.0"
  @spec validate_all([String.t()]) :: [{String.t(), ExGtin.result()}]
  def validate_all(codes) do
    Enum.map(codes, fn code -> {code, safe_validate(code)} end)
  end

  @doc """
  Partitions a list of codes into valid and invalid buckets.

  Runs each element of `codes` through `ExGtin.validate/1` and returns a map
  with `:valid` (inputs that produced `{:ok, _}`) and `:invalid` (inputs that
  produced `{:error, _}`). Order is preserved within each bucket and individual
  items never raise. An empty list returns empty buckets.

  ## Examples

      iex> ExGtin.Batch.partition(["6291041500213", "6291041500214"])
      %{valid: ["6291041500213"], invalid: ["6291041500214"]}

      iex> ExGtin.Batch.partition([])
      %{valid: [], invalid: []}

  """
  @doc since: "1.4.0"
  @spec partition([String.t()]) :: %{valid: [String.t()], invalid: [String.t()]}
  def partition(codes) do
    {valid, invalid} =
      Enum.split_with(codes, fn code ->
        match?({:ok, _}, safe_validate(code))
      end)

    %{valid: valid, invalid: invalid}
  end

  # `ExGtin.validate/1` only guards on length: a wrong-length input returns an
  # `{:error, _}` tuple, but a correct-length input with non-digit characters
  # raises `ArgumentError` from the underlying integer conversion. The batch
  # contract is that no individual item ever aborts the batch, so any
  # raised error is caught here and reported as `{:error, "Invalid Code"}`.
  @spec safe_validate(term()) :: ExGtin.result()
  defp safe_validate(code) do
    ExGtin.validate(code)
  rescue
    _ -> {:error, "Invalid Code"}
  end
end
