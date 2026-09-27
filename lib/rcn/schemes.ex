defmodule ExGtin.RCN.Schemes do
  @moduledoc """
  Named restricted-circulation-number (RCN) variable-measure schemes, as data.

  A restricted-circulation number that carries an embedded price or weight has
  no single, universal layout: the exact digit positions of the item reference,
  the embedded amount, and any internal check digit are **defined by the region
  or retailer** that issues the code. Because of that, this library never
  assumes one global layout. Instead a *scheme* — a plain map describing the
  field layout — is always supplied explicitly, and the schemes shipped here are
  documented, illustrative defaults that callers can freely override with their
  own scheme map.

  A scheme is a `t:rcn_scheme/0` map:

    * `prefix` — the leading digit strings the scheme applies to (for example
      `["2"]`). Decoding rejects a code whose prefix is not listed.
    * `item` — a 1-based, inclusive `Range.t()` of digit positions into the
      GTIN-13 that make up the item reference.
    * `embedded` — `{:price, range}` or `{:weight, range}`, where `range` is the
      1-based, inclusive `Range.t()` of digit positions carrying the embedded
      price or weight.
    * `check` — either `nil` (no internal check digit) or
      `{:price_check, position}` naming the 1-based digit position of an internal
      price/weight check digit.

  Digit positions are 1-based into a 13-digit GTIN-13, where position 1 is the
  leading digit and position 13 is the GTIN-13 check digit.

  ## Shipped schemes

  These are illustrative layouts on the `"2"` prefix. Real deployments vary by
  retailer and region; treat them as sensible defaults and override as needed.

  ### `:gs1_germany_price`

  A GS1 Germany / EU-style price-embedded scheme on prefix `"2"` that carries an
  **internal price check digit**, exercising the `check: {:price_check, _}` path.

      pos:  1  2  3  4  5  6  7  8  9 10 11 12 13
            P  I  I  I  I  I  C  A  A  A  A  A  G

    * `1`      — prefix digit `"2"`.
    * `2`–`6`  — item reference (5 digits).
    * `7`      — internal price check digit.
    * `8`–`12` — embedded price/amount (5 digits).
    * `13`     — GTIN-13 check digit.

  The internal check digit at position `7` uses an **illustrative convention**:
  a standard GS1 mod-10 check digit computed over the embedded price field
  (positions `8`–`12`) via the shared `ExGtin.CheckDigit.mod10/1` engine.
  Decoding rejects a code whose position-`7` digit does not match. This keeps the
  shipped scheme self-consistent and testable against the library's shared
  check-digit engine; real region/retailer price-embedded schemes may define a
  different price-check algorithm, in which case supply a scheme with
  `check: nil` and validate the digit in your own layer.

  ### `:gs1_embedded_weight`

  A weight-embedded scheme on prefix `"2"` with **no internal check digit**,
  exercising the `check: nil` path.

      pos:  1  2  3  4  5  6  7  8  9 10 11 12 13
            P  I  I  I  I  I  I  W  W  W  W  W  G

    * `1`      — prefix digit `"2"`.
    * `2`–`7`  — item reference (6 digits).
    * `8`–`12` — embedded weight (5 digits).
    * `13`     — GTIN-13 check digit.

  This module only supplies the scheme *data* plus lookup accessors
  (`fetch/1`, `fetch!/1`, `all/0`). The decoding logic that reads a code against
  a scheme lives in `ExGtin.RCN`.
  """
  @moduledoc since: "1.5.0"

  @typedoc """
  A variable-measure RCN scheme describing the GTIN-13 field layout.

    * `prefix` — leading digit strings the scheme applies to.
    * `item` — 1-based inclusive digit-position range of the item reference.
    * `embedded` — `{:price | :weight, range}` of the embedded amount's
      1-based inclusive digit-position range.
    * `check` — `nil`, or `{:price_check, position}` naming an internal
      price/weight check digit's 1-based position.
  """
  @type rcn_scheme :: %{
          prefix: [String.t()],
          item: Range.t(),
          embedded: {:price | :weight, Range.t()},
          check: nil | {:price_check, non_neg_integer}
        }

  # Named schemes as data. Add markets by editing this map — no logic changes.
  @schemes %{
    gs1_germany_price: %{
      prefix: ["2"],
      item: 2..6,
      embedded: {:price, 8..12},
      check: {:price_check, 7}
    },
    gs1_embedded_weight: %{
      prefix: ["2"],
      item: 2..7,
      embedded: {:weight, 8..12},
      check: nil
    }
  }

  @doc """
  Returns all shipped schemes as a map of scheme name to `t:rcn_scheme/0`.

  ## Examples

      iex> schemes = ExGtin.RCN.Schemes.all()
      iex> schemes[:gs1_germany_price].embedded
      {:price, 8..12}

      iex> ExGtin.RCN.Schemes.all() |> Map.keys() |> Enum.sort()
      [:gs1_embedded_weight, :gs1_germany_price]

  """
  @doc since: "1.5.0"
  @spec all() :: %{optional(atom) => rcn_scheme}
  def all, do: @schemes

  @doc """
  Fetches a shipped scheme by its named atom.

  Returns `{:ok, scheme}` when the name is known, or
  `{:error, reason}` when it is not.

  ## Examples

      iex> ExGtin.RCN.Schemes.fetch(:gs1_embedded_weight)
      {:ok, %{prefix: ["2"], item: 2..7, embedded: {:weight, 8..12}, check: nil}}

      iex> ExGtin.RCN.Schemes.fetch(:no_such_scheme)
      {:error, "Unknown RCN scheme: :no_such_scheme"}

  """
  @doc since: "1.5.0"
  @spec fetch(atom) :: {:ok, rcn_scheme} | {:error, String.t()}
  def fetch(name) when is_atom(name) do
    case Map.fetch(@schemes, name) do
      {:ok, scheme} -> {:ok, scheme}
      :error -> {:error, "Unknown RCN scheme: #{inspect(name)}"}
    end
  end

  @doc """
  Fetches a shipped scheme by its named atom, raising when unknown.

  ## Examples

      iex> ExGtin.RCN.Schemes.fetch!(:gs1_germany_price).check
      {:price_check, 7}

  """
  @doc since: "1.5.0"
  @spec fetch!(atom) :: rcn_scheme
  def fetch!(name) when is_atom(name) do
    case fetch(name) do
      {:ok, scheme} -> scheme
      {:error, reason} -> raise ArgumentError, reason
    end
  end
end
