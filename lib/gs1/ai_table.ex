defmodule ExGtin.GS1.AITable do
  @moduledoc """
  GS1 Application Identifier (AI) dictionary as static data.

  The parser's behavior is driven by this table rather than by control flow, so
  the supported AI set grows by editing data — no parsing logic changes. Each
  entry maps an AI code (a string such as `"01"`) to a `{name, kind, format}`
  tuple where:

    * `name` is a human-readable label for the AI.
    * `kind` is `{:fixed, len}` for a fixed-length value of exactly `len`
      characters, or `{:variable, max_len}` for a variable-length value of up to
      `max_len` characters terminated by the FNC1/GS separator.
    * `format` is an atom describing the data format (for example `:numeric`,
      `:alphanumeric`, or `:date`).

  This module ships a bounded, documented AI set. The full GS1 General
  Specifications AI table (hundreds of entries) can be added incrementally by
  extending `@ai_table` without touching the element-string parser.
  """
  @moduledoc since: "1.5.0"

  @typedoc "The classification and length constraint of an AI value."
  @type kind :: {:fixed, pos_integer} | {:variable, pos_integer}

  @typedoc "A dictionary entry: the AI's name, its kind, and its data format."
  @type ai_entry :: {name :: String.t(), kind :: kind, format :: atom}

  # AI code -> {name, kind, format}. Fixed-length values carry their exact
  # length; variable-length values carry their maximum length and are terminated
  # by the FNC1/GS separator.
  #
  # The 3xx measurement AIs (weight, dimensions, area, volume) are four digits
  # where the final digit is the implied-decimal-point indicator: the value is
  # always six numeric digits and the last AI digit says how many of those digits
  # are fractional. GS1 assigns decimal indicators 0..5, so each measurement
  # family expands to six concrete AI codes (for example 3100..3105 for net
  # weight in kilograms). Only the weight families are included in this initial
  # set; the remaining 3xx dimension/area/volume families can be added later as a
  # pure data edit.
  @weight_families %{
    "310" => "Net Weight (kg)",
    "320" => "Net Weight (lb)",
    "330" => "Gross Weight (kg)",
    "340" => "Gross Weight (lb)",
    "356" => "Net Weight (troy ounce)"
  }

  # Decimal-point indicators GS1 assigns to the 3xx measurement AIs.
  @decimal_indicators 0..5

  @weight_ai_entries for {prefix, name} <- @weight_families,
                         d <- @decimal_indicators,
                         into: %{},
                         do: {"#{prefix}#{d}", {name, {:fixed, 6}, :numeric}}

  @ai_table Map.merge(
              %{
                "01" => {"GTIN", {:fixed, 14}, :numeric},
                "10" => {"Batch/Lot Number", {:variable, 20}, :alphanumeric},
                "11" => {"Production Date", {:fixed, 6}, :date},
                "13" => {"Packaging Date", {:fixed, 6}, :date},
                "15" => {"Best Before Date", {:fixed, 6}, :date},
                "17" => {"Expiration Date", {:fixed, 6}, :date},
                "21" => {"Serial Number", {:variable, 20}, :alphanumeric}
              },
              @weight_ai_entries
            )

  @doc """
  Returns the full AI dictionary as a map of AI code to `{name, kind, format}`.

  ## Examples

      iex> table = ExGtin.GS1.AITable.ai_table()
      iex> table["01"]
      {"GTIN", {:fixed, 14}, :numeric}

  """
  @doc since: "1.5.0"
  @spec ai_table() :: %{optional(String.t()) => ai_entry}
  def ai_table, do: @ai_table

  @doc """
  Looks up a single AI code, returning its entry or `:error`.

  ## Examples

      iex> ExGtin.GS1.AITable.lookup("10")
      {:ok, {"Batch/Lot Number", {:variable, 20}, :alphanumeric}}

      iex> ExGtin.GS1.AITable.lookup("99")
      :error

  """
  @doc since: "1.5.0"
  @spec lookup(String.t()) :: {:ok, ai_entry} | :error
  def lookup(code) do
    case Map.fetch(@ai_table, code) do
      {:ok, entry} -> {:ok, entry}
      :error -> :error
    end
  end
end
