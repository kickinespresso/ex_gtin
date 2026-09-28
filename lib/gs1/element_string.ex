defmodule ExGtin.GS1.ElementString do
  @moduledoc """
  Parser for GS1-128 / Application Identifier (AI) element strings.

  An element string concatenates one or more `AI + value` pairs. GS1 defines two
  serializations of the same logical payload:

    * the **parenthesized** human-readable form, `(01)06291041500213(10)ABC123`,
      where each `(NN...)` introduces an AI and the characters up to the next
      `(` are its value; and
    * the **raw FNC1** scanner form, where fixed-length AIs are concatenated
      without a separator and variable-length AIs are terminated by the FNC1/GS
      separator (`<GS>`, ASCII 29) or the end of the payload.

  Both forms normalize into one core walker that reads an AI code, looks it up in
  `ExGtin.GS1.AITable`, extracts the value, and accumulates a `%{ai => value}`
  result map. The walker disambiguates the 2–4 digit AI code using the dictionary
  itself, so the supported set grows as a data edit in `ExGtin.GS1.AITable`.

  This module currently implements the shared core walker and the parenthesized
  front door. The raw FNC1 front door, embedded GTIN validation, and the public
  entry point are layered on top of it in later work.

  ## Date AIs

  Date-format AIs (11 Production Date, 13 Packaging Date, 15 Best Before Date,
  17 Expiration Date) carry a six-digit `YYMMDD` value. By default the parser is
  lossless: it surfaces these values as the raw `YYMMDD` string, exactly as they
  appear in the payload, so callers keep full control over how (and whether) to
  interpret them.

  Date interpretation is **opt-in** via the `:dates` option:

    * `dates: :raw` (the default) — leave date AI values as the raw `YYMMDD`
      string.
    * `dates: :parsed` — interpret date AI values into an Elixir `Date` struct.

  When `dates: :parsed` is requested, the two-digit `YY` is mapped to a full year
  using the GS1 rule: the resulting year falls in the window
  `[current_year - 49, current_year + 50]`, so a scanned date is read relative to
  the current date rather than assuming a fixed century.

  GS1 allows the `DD` field to be `"00"`, meaning "no specific day / end of the
  month". This parser interprets a `"00"` day as the **last day of that month**
  (for example `2612` → `2026-12-31`), which yields a valid `Date` while
  preserving the "end of month" intent. A date value that is not six digits, or
  whose month/day is otherwise invalid, is reported as
  `{:invalid_date, code, value}`; callers that want the raw bytes regardless
  should use the default `dates: :raw`.

  ## Errors

  All parsing errors are `{:error, tuple}` and carry enough context to locate the
  problem in the payload:

    * `{:unknown_ai, code, position}` — an AI `code` that is not in
      `ExGtin.GS1.AITable`, at byte `position` in the payload.
    * `{:invalid_length, code, expected, actual, position}` — a fixed-length AI
      `code` whose value was `actual` characters where the dictionary requires
      `expected`, at byte `position`.
    * `{:unbalanced_parentheses, position}` — a parenthesized payload with a
      missing `(` or `)`, at byte `position`.
    * `{:invalid_gtin, value}` — an AI 01 (GTIN) `value` whose mod-10 check digit
      did not validate, or that contained non-digit characters. The embedded
      GTIN is validated via `ExGtin.CheckDigit` so callers can trust an extracted
      AI 01 value.
    * `{:invalid_date, code, value}` — a date AI `code` (11/13/15/17) whose
      `YYMMDD` `value` could not be interpreted as a calendar date, reported only
      when date interpretation was requested with `dates: :parsed`.

  The raw walker and the parenthesized front door produce the same error shapes,
  so callers handle one set of tuples regardless of the input serialization.

  ## Partial parses and the unparsed remainder

  A fully interpreted payload returns the 2-tuple `{:ok, map}`. When parsing
  succeeds for a leading portion of the payload but then reaches trailing input
  that cannot be interpreted — an unknown AI, or leftover bytes that do not form
  a known AI code — after at least one AI+value pair has already been read, the
  parser does **not** silently drop the tail. Instead it returns the 3-tuple
  `{:ok, map, unparsed}`, where `unparsed` is the leftover string, so partial or
  garbage-suffixed payloads are diagnosable rather than lossy.

  The distinction is deliberate:

    * Nothing parsed yet (the very first AI is already uninterpretable) is a hard
      `{:error, {:unknown_ai, _, _}}` — a wholly unparseable payload is an error,
      not a partial success.
    * Malformed-data errors (`:invalid_length`, `:invalid_gtin`, `:invalid_date`,
      `:unbalanced_parentheses`) remain `{:error, _}` even after progress, since
      they signal bad data rather than merely uninterpretable trailing input.

  Only the "unknown AI / cannot segment further" case encountered after progress
  is surfaced as a remainder.
  """
  @moduledoc since: "1.5.0"

  alias ExGtin.CheckDigit
  alias ExGtin.GS1.AITable

  # AI 01 carries a GTIN whose embedded value is validated with the shared
  # mod-10 check-digit engine.
  @gtin_ai "01"

  # GS1 year window: a two-digit YY maps to the year in the range
  # [current year - 49, current year + 50]. `@gs1_year_lookback` years are read
  # as the recent past and the remainder of the 100-year window as the future.
  @gs1_year_lookback 49

  @typedoc """
  A parsed element-string value.

  Values are raw strings as read from the payload. When date interpretation is
  requested (`dates: :parsed`), date-format AI values (11/13/15/17) are `Date`
  structs instead of raw `YYMMDD` strings.
  """
  @type value :: String.t() | Date.t()

  @typedoc "A parsed element string: AI code (as a string) mapped to its value."
  @type parsed :: %{optional(String.t()) => value}

  @typedoc """
  A parse result.

  A fully interpreted payload returns `{:ok, parsed}`. When parsing succeeds for
  a leading portion of the payload but hits trailing input it cannot interpret
  (an unknown AI, or leftover bytes that do not form a known AI code) after at
  least one AI+value pair has been read, the leftover string is surfaced as an
  `unparsed` remainder in a 3-tuple `{:ok, parsed, unparsed}` rather than being
  silently dropped. A payload that cannot be interpreted at all — nothing parsed
  before the failure — is an `{:error, error}` instead of a partial parse.
  """
  @type result ::
          {:ok, parsed}
          | {:ok, parsed, unparsed :: String.t()}
          | {:error, error}

  @typedoc """
  Parser options.

    * `:dates` — how to surface date-format AI values (11/13/15/17). `:raw`
      (the default) keeps the raw `YYMMDD` string; `:parsed` interprets it into
      an Elixir `Date`.
  """
  @type option :: {:dates, :raw | :parsed}
  @type options :: [option]

  @typedoc """
  A structured parse error.

    * `{:unknown_ai, code, position}` — unknown AI `code` at `position`.
    * `{:invalid_length, code, expected, actual, position}` — fixed-length AI
      `code` had `actual` characters, `expected` were required, at `position`.
    * `{:unbalanced_parentheses, position}` — malformed parentheses at `position`.
    * `{:invalid_gtin, value}` — AI 01 (GTIN) `value` failed check-digit
      validation or was non-numeric.
    * `{:invalid_date, code, value}` — date AI `code` `value` could not be
      interpreted as a calendar date under `dates: :parsed`.
  """
  @type error ::
          {:unknown_ai, code :: String.t(), position :: non_neg_integer}
          | {:invalid_length, code :: String.t(), expected :: pos_integer,
             actual :: non_neg_integer, position :: non_neg_integer}
          | {:unbalanced_parentheses, position :: non_neg_integer}
          | {:invalid_gtin, value :: String.t()}
          | {:invalid_date, code :: String.t(), value :: String.t()}

  # AI codes in the current dictionary are 2–4 digits. The walker tries the
  # known lengths shortest-first and disambiguates against the AI table.
  @ai_code_lengths [2, 3, 4]

  @doc """
  Walks a normalized payload, accumulating an `%{ai => value}` result map.

  The walker repeatedly reads the next AI code, looks it up in the AI dictionary,
  extracts the AI's value (by fixed length or up to the FNC1/GS separator), and
  accumulates the pair into the result map. It returns `{:ok, map}` when the
  whole payload is consumed, or `{:ok, map, unparsed}` when a leading portion
  parses but uninterpretable trailing input remains (see the "Partial parses and
  the unparsed remainder" section in the module documentation).

  This is the shared core used by both the parenthesized and raw FNC1 front
  doors. Front doors are responsible for normalizing their input (for example,
  stripping parentheses) before handing the payload to the walker.

  Accepts the same options as the front doors; see the "Date AIs" section in the
  module documentation for the `:dates` option. Date interpretation defaults to
  `dates: :raw`.
  """
  @doc since: "1.5.0"
  @spec walk(String.t(), options) :: result
  def walk(payload, opts \\ []) when is_binary(payload) and is_list(opts) do
    do_walk(payload, 0, %{}, opts)
  end

  @doc """
  Parses the human-readable parenthesized element-string form.

  Each `(NN...)` group introduces an AI and the characters up to the next `(`
  (or the end of the string) are its value, so the form is self-delimiting and
  does not need the raw walker's length-based segmentation. Every AI is still
  validated against `ExGtin.GS1.AITable`, and fixed-length AI values are checked
  against the dictionary length.

  Returns `{:ok, map}` mapping each AI code (as a string) to its value.

  Date-format AIs (11/13/15/17) are surfaced as their raw `YYMMDD` string by
  default. Pass `dates: :parsed` to interpret them into Elixir `Date` structs
  instead; see the "Date AIs" section in the module documentation for the year
  window and `"00"`-day behavior.

  ## Examples

      iex> ExGtin.GS1.ElementString.parse_parenthesized("(01)06291041500213(17)261231(10)ABC123")
      {:ok, %{"01" => "06291041500213", "17" => "261231", "10" => "ABC123"}}

  With `dates: :parsed`, the expiration date (AI 17) is interpreted into a `Date`
  while the raw default leaves it as `"261231"`:

      iex> ExGtin.GS1.ElementString.parse_parenthesized("(01)06291041500213(17)261231", dates: :parsed)
      {:ok, %{"01" => "06291041500213", "17" => ~D[2026-12-31]}}

  """
  @doc since: "1.5.0"
  @spec parse_parenthesized(String.t(), options) :: result
  def parse_parenthesized(payload, opts \\ []) when is_binary(payload) and is_list(opts) do
    do_parse_parenthesized(payload, 0, %{}, opts)
  end

  @doc """
  Parses the raw FNC1 scanner element-string form.

  In the raw form there are no parentheses: AI codes and values are concatenated
  directly. Fixed-length AIs are segmented by their dictionary length, and
  variable-length AIs run up to the FNC1/GS separator (`<GS>`, ASCII 29) or, when
  they are the last element with no trailing separator, to the end of the
  payload. Every AI is validated against `ExGtin.GS1.AITable`.

  This is the raw front door; it normalizes the payload straight into the shared
  core walker (`walk/1`), so it returns the same `{:ok, map}` result and the same
  error shapes as `parse_parenthesized/1`. The raw and parenthesized forms of the
  same logical payload therefore produce equal maps.

  Returns `{:ok, map}` mapping each AI code (as a string) to its value.

  ## Examples

  A fixed-length GTIN (AI 01) followed by a variable-length batch (AI 10)
  terminated by the FNC1/GS separator, then a serial number (AI 21) consuming the
  remainder:

      iex> ExGtin.GS1.ElementString.parse_raw("010629104150021310ABC123" <> <<29>> <> "21XYZ789")
      {:ok, %{"01" => "06291041500213", "10" => "ABC123", "21" => "XYZ789"}}

  A single fixed-length AI needs no separator:

      iex> ExGtin.GS1.ElementString.parse_raw("0106291041500213")
      {:ok, %{"01" => "06291041500213"}}

  Date-format AIs (11/13/15/17) are raw `YYMMDD` by default; pass `dates: :parsed`
  to interpret them into Elixir `Date` structs (see the "Date AIs" section in the
  module documentation):

      iex> ExGtin.GS1.ElementString.parse_raw("17261231", dates: :parsed)
      {:ok, %{"17" => ~D[2026-12-31]}}

  """
  @doc since: "1.5.0"
  @spec parse_raw(String.t(), options) :: result
  def parse_raw(payload, opts \\ []) when is_binary(payload) and is_list(opts) do
    walk(payload, opts)
  end

  # Walks the parenthesized payload segment by segment. Each iteration expects an
  # opening `(`, reads the AI code up to the closing `)`, then takes the value up
  # to the next `(`. Position tracks the byte offset into the original string for
  # error context.
  @spec do_parse_parenthesized(String.t(), non_neg_integer, parsed, options) :: result
  defp do_parse_parenthesized("", _position, acc, _opts), do: {:ok, acc}

  defp do_parse_parenthesized(payload, position, acc, opts) do
    with {:ok, code, value, consumed, rest} <- read_segment(payload, position),
         {:ok, entry} <- lookup_ai(code, position),
         :ok <- validate_segment_value(entry, code, value, position),
         :ok <- validate_embedded(code, value),
         {:ok, interpreted} <- interpret_value(entry, code, value, opts) do
      do_parse_parenthesized(rest, position + consumed, Map.put(acc, code, interpreted), opts)
    else
      error -> resolve_remainder(error, payload, acc)
    end
  end

  # Reads a single `(code)value` segment from the front of the payload. Returns
  # the AI code, its value, the number of characters consumed (including the
  # parentheses), and the rest of the payload. A payload that does not start with
  # `(` or that is missing its closing `)` is a malformed-parentheses error.
  @spec read_segment(String.t(), non_neg_integer) ::
          {:ok, String.t(), String.t(), non_neg_integer, String.t()} | {:error, error}
  defp read_segment("(" <> rest, position) do
    case :binary.split(rest, ")") do
      [code, after_close] ->
        {value, value_rest} = take_value(after_close)
        # consumed = "(" + code + ")" + value
        consumed = 1 + byte_size(code) + 1 + byte_size(value)
        {:ok, code, value, consumed, value_rest}

      [_no_close] ->
        {:error, {:unbalanced_parentheses, position}}
    end
  end

  defp read_segment(_payload, position) do
    {:error, {:unbalanced_parentheses, position}}
  end

  # Takes the value characters up to (but not including) the next `(`, which
  # begins the following segment. When no further `(` is present, the remaining
  # characters are the whole value and nothing is left.
  @spec take_value(String.t()) :: {String.t(), String.t()}
  defp take_value(payload) do
    case :binary.split(payload, "(") do
      [value, next] -> {value, "(" <> next}
      [value] -> {value, ""}
    end
  end

  # Validates a segment's value against its dictionary entry. Fixed-length AIs
  # must match the recorded length exactly; variable-length AIs are accepted as
  # read since the parenthesized form is self-delimiting. A wrong fixed-length
  # value reports the offending AI code, the expected and actual lengths, and the
  # position, matching the raw walker's `:invalid_length` shape.
  @spec validate_segment_value(AITable.ai_entry(), String.t(), String.t(), non_neg_integer) ::
          :ok | {:error, error}
  defp validate_segment_value({_name, {:fixed, len}, _format}, code, value, position) do
    actual = byte_size(value)

    if actual == len do
      :ok
    else
      {:error, {:invalid_length, code, len, actual, position}}
    end
  end

  defp validate_segment_value({_name, {:variable, _max_len}, _format}, _code, _value, _position) do
    :ok
  end

  # Validates embedded identifiers as their AI is accumulated, shared by both the
  # parenthesized and raw front doors. Only AI 01 (GTIN) carries an embedded
  # identifier today: its value's mod-10 check digit is verified with the shared
  # `ExGtin.CheckDigit` engine. A GTIN that fails validation — or that contains
  # non-digit characters — is reported as `{:invalid_gtin, value}`. Every other
  # AI passes through unchanged.
  @spec validate_embedded(String.t(), String.t()) :: :ok | {:error, error}
  defp validate_embedded(@gtin_ai, value) do
    with {:ok, digits} <- to_digits(value),
         true <- CheckDigit.valid?(digits) do
      :ok
    else
      _invalid -> {:error, {:invalid_gtin, value}}
    end
  end

  defp validate_embedded(_code, _value), do: :ok

  # Converts a GTIN value string into the `list(0..9)` the check-digit engine
  # expects. A single non-digit character makes the whole value invalid, so a
  # non-numeric GTIN is rejected rather than crashing the parser.
  @spec to_digits(String.t()) :: {:ok, list(0..9)} | :error
  defp to_digits(value) do
    value
    |> String.to_charlist()
    |> Enum.reduce_while({:ok, []}, fn char, {:ok, acc} ->
      if char in ?0..?9 do
        {:cont, {:ok, [char - ?0 | acc]}}
      else
        {:halt, :error}
      end
    end)
    |> case do
      {:ok, reversed} -> {:ok, Enum.reverse(reversed)}
      :error -> :error
    end
  end

  # Interprets an AI's raw value according to the parser options, shared by both
  # front doors. Only date-format AIs are affected, and only when the caller
  # opts in with `dates: :parsed`; every other AI (and the `dates: :raw` default)
  # passes the raw string through unchanged, keeping the default output lossless.
  @spec interpret_value(AITable.ai_entry(), String.t(), String.t(), options) ::
          {:ok, value} | {:error, error}
  defp interpret_value({_name, _kind, :date}, code, value, opts) do
    case Keyword.get(opts, :dates, :raw) do
      :parsed -> parse_date(code, value)
      _raw -> {:ok, value}
    end
  end

  defp interpret_value(_entry, _code, value, _opts), do: {:ok, value}

  # Interprets a GS1 `YYMMDD` date value into an Elixir `Date`. The two-digit year
  # is resolved against the GS1 window `[current year - 49, current year + 50]`,
  # and a `"00"` day (GS1 "end of month / no specific day") becomes the last day
  # of the resolved month. Anything that is not six digits, or that does not form
  # a valid calendar date, is reported as `{:invalid_date, code, value}`.
  @spec parse_date(String.t(), String.t()) :: {:ok, Date.t()} | {:error, error}
  defp parse_date(code, <<yy::binary-size(2), mm::binary-size(2), dd::binary-size(2)>> = value) do
    with {:ok, yy} <- parse_int(yy),
         {:ok, mm} <- parse_int(mm),
         {:ok, dd} <- parse_int(dd),
         year = gs1_full_year(yy),
         {:ok, date} <- build_date(year, mm, dd) do
      {:ok, date}
    else
      _invalid -> {:error, {:invalid_date, code, value}}
    end
  end

  defp parse_date(code, value), do: {:error, {:invalid_date, code, value}}

  # Builds a `Date`, treating a `00` day as the last day of the resolved month.
  @spec build_date(integer, 1..12, 0..31) :: {:ok, Date.t()} | {:error, term}
  defp build_date(year, month, 0) do
    with {:ok, first} <- Date.new(year, month, 1) do
      {:ok, Date.end_of_month(first)}
    end
  end

  defp build_date(year, month, day), do: Date.new(year, month, day)

  # Resolves a two-digit GS1 year into a full year using the GS1 rule: the result
  # lies in `[current year - 49, current year + 50]`. Starting from the current
  # century's candidate, shift by a century if it falls outside the lookback
  # window so recent-past dates resolve to the previous century.
  @spec gs1_full_year(0..99) :: integer
  defp gs1_full_year(yy) do
    current_year = Date.utc_today().year
    century = div(current_year, 100) * 100
    candidate = century + yy

    cond do
      candidate > current_year + (100 - @gs1_year_lookback) - 1 -> candidate - 100
      candidate < current_year - @gs1_year_lookback -> candidate + 100
      true -> candidate
    end
  end

  # Parses an all-digit string into a non-negative integer, rejecting any value
  # with non-digit characters so a malformed date surfaces as an error rather
  # than crashing.
  @spec parse_int(String.t()) :: {:ok, non_neg_integer} | :error
  defp parse_int(string) do
    case Integer.parse(string) do
      {int, ""} when int >= 0 -> {:ok, int}
      _invalid -> :error
    end
  end

  # Empty payload / fully consumed: the accumulated map is the result.
  @spec do_walk(String.t(), non_neg_integer, parsed, options) :: result
  defp do_walk("", _position, acc, _opts), do: {:ok, acc}

  defp do_walk(payload, position, acc, opts) do
    with {:ok, code, code_len, rest} <- read_ai_code(payload, position),
         {:ok, entry} <- lookup_ai(code, position),
         {:ok, value, value_len, rest} <- extract_value(entry, code, rest, position + code_len),
         :ok <- validate_embedded(code, value),
         {:ok, interpreted} <- interpret_value(entry, code, value, opts) do
      next_position = position + code_len + value_len
      do_walk(rest, next_position, Map.put(acc, code, interpreted), opts)
    else
      error -> resolve_remainder(error, payload, acc)
    end
  end

  # Decides whether a walker failure is a hard error or a partial parse. Only the
  # "cannot interpret this input" cases (an unknown AI, or leftover bytes that do
  # not form a known AI code) become a partial parse, and only once at least one
  # AI+value pair has already been accumulated: the uninterpretable tail is
  # surfaced as the `unparsed` remainder rather than dropped. With nothing parsed
  # yet (`acc == %{}`) the payload is a hard error, and malformed-data errors
  # (wrong fixed length, invalid GTIN, invalid date) stay errors regardless of
  # progress, since they signal bad data rather than merely uninterpretable
  # trailing input.
  @spec resolve_remainder({:error, error}, String.t(), parsed) :: result
  defp resolve_remainder({:error, {:unknown_ai, _code, _position}}, remainder, acc)
       when acc != %{} do
    {:ok, acc, remainder}
  end

  defp resolve_remainder(error, _remainder, _acc), do: error

  # Reads the next AI code from the front of the payload. AI codes are 2–4 digits
  # and are disambiguated against the AI table: the walker takes the first known
  # code, trying candidate lengths shortest-first. When no known code prefixes
  # the payload, an `{:unknown_ai, code, position}` error names the candidate
  # code and its byte position.
  @spec read_ai_code(String.t(), non_neg_integer) ::
          {:ok, String.t(), pos_integer, String.t()} | {:error, error}
  defp read_ai_code(payload, position) do
    case Enum.find_value(@ai_code_lengths, &known_ai_at_length(payload, &1)) do
      {code, len, rest} -> {:ok, code, len, rest}
      nil -> {:error, {:unknown_ai, candidate_code(payload), position}}
    end
  end

  # When no known AI prefixes the payload, report the candidate code the walker
  # tried to match rather than the whole remaining payload: the leading digits up
  # to the longest AI-code length (or the whole remainder if it is shorter). This
  # keeps the `:unknown_ai` error focused on the offending code.
  @spec candidate_code(String.t()) :: String.t()
  defp candidate_code(payload) do
    max_len = Enum.max(@ai_code_lengths)
    binary_part(payload, 0, min(byte_size(payload), max_len))
  end

  # If the payload begins with a known AI code of exactly `len` digits, returns
  # `{code, len, rest}`; otherwise `nil` so the caller can try the next length.
  @spec known_ai_at_length(String.t(), pos_integer) ::
          {String.t(), pos_integer, String.t()} | nil
  defp known_ai_at_length(payload, len) when byte_size(payload) >= len do
    <<code::binary-size(^len), rest::binary>> = payload

    case AITable.lookup(code) do
      {:ok, _entry} -> {code, len, rest}
      :error -> nil
    end
  end

  defp known_ai_at_length(_payload, _len), do: nil

  # Looks up an AI code in the dictionary. Kept separate from reading so a code
  # that parses structurally but is not in the dictionary still surfaces an
  # `{:unknown_ai, code, position}` error with the position.
  @spec lookup_ai(String.t(), non_neg_integer) ::
          {:ok, AITable.ai_entry()} | {:error, error}
  defp lookup_ai(code, position) do
    case AITable.lookup(code) do
      {:ok, entry} -> {:ok, entry}
      :error -> {:error, {:unknown_ai, code, position}}
    end
  end

  # Extracts an AI's value from the remaining payload:
  #
  #   * fixed-length AIs take exactly the dictionary length; too little data is a
  #     wrong-fixed-length error carrying the offending AI code, the expected
  #     length, the actual length available, and the position;
  #   * variable-length AIs take up to the FNC1/GS separator (ASCII 29) or the end
  #     of the payload, bounded by the dictionary maximum length.
  #
  # Returns the value, the number of payload characters it consumed (including a
  # trailing separator, if any), and the rest of the payload.
  @spec extract_value(AITable.ai_entry(), String.t(), String.t(), non_neg_integer) ::
          {:ok, String.t(), non_neg_integer, String.t()} | {:error, error}
  defp extract_value({_name, {:fixed, len}, _format}, code, payload, position) do
    case payload do
      <<value::binary-size(^len), rest::binary>> ->
        {:ok, value, len, rest}

      _too_short ->
        {:error, {:invalid_length, code, len, byte_size(payload), position}}
    end
  end

  defp extract_value({_name, {:variable, _max_len}, _format}, _code, payload, _position) do
    case :binary.split(payload, <<29>>) do
      [value, rest] -> {:ok, value, byte_size(value) + 1, rest}
      [value] -> {:ok, value, byte_size(value), ""}
    end
  end
end
