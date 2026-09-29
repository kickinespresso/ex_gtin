defmodule ExGtin do
  @moduledoc """
  Documentation for ExGtin. This library provides
  functionality for validating GTIN compliant codes.
  """
  @moduledoc since: "1.0.1"

  import ExGtin.Validation

  alias ExGtin.Convert.Bookland
  alias ExGtin.Convert.GTIN14
  alias ExGtin.Convert.UPC
  alias ExGtin.Fix
  alias ExGtin.GS1.ElementString
  alias ExGtin.RCN

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
  Converts a GTIN or ISBN to GTIN-14 format.

  Accepts an optional `indicator` digit (`0..9`, default `1`) that becomes the
  leading digit of the emitted GTIN-14. The check digit is recomputed over the
  full 13-digit body so the result validates as a GTIN-14.

  Calling `normalize/1` (without an indicator) behaves exactly as before,
  using indicator `1`.

  ## Examples

      iex> ExGtin.normalize("6291041500213")
      {:ok, "16291041500210"}

      iex> ExGtin.normalize("6291041500213", 5)
      {:ok, "56291041500218"}
  """
  @doc since: "1.1.0"
  @spec normalize(binary | integer | list(number)) :: result
  def normalize(gtin), do: do_normalize(gtin, :default)

  @doc """
  Converts a GTIN or ISBN to GTIN-14 format using the supplied `indicator`
  digit (`0..9`) as the leading digit. See `normalize/1`.

  Returns `{:error, _}` when the indicator is outside `0..9`.

  ## Examples

      iex> ExGtin.normalize("6291041500213", 5)
      {:ok, "56291041500218"}
  """
  @doc since: "1.4.0"
  @spec normalize(binary | integer | list(number), integer) :: result
  def normalize(gtin, indicator), do: do_normalize(gtin, indicator)

  defp do_normalize(gtin, indicator) when is_list(gtin),
    do: do_normalize(Enum.join(gtin), indicator)

  defp do_normalize(_gtin, indicator) when indicator != :default and indicator not in 0..9 do
    {:error, "Invalid indicator digit; must be in 0..9"}
  end

  defp do_normalize(gtin, indicator) do
    with {:ok, type} <- do_gtin_check_digit(gtin),
         do: {:ok, normalize_gtin(gtin, type, indicator)}
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

  defp normalize_gtin(gtin, "GTIN-8", indicator) do
    digits = String.codepoints(gtin) |> Enum.map(&String.to_integer/1)
    {code, _} = Enum.split(digits, 7)
    build_gtin14([resolve_indicator(indicator, 1), 0, 0, 0, 0, 0] ++ code)
  end

  defp normalize_gtin(gtin, "ISBN-10", indicator) do
    code =
      gtin
      |> String.codepoints()
      |> Enum.take(9)
      |> Enum.map(&String.to_integer/1)

    # ISBN-10 historically pads to GTIN-14 with a leading 0 (Bookland 978),
    # so its default leading digit is 0 rather than the GTIN-14 default of 1.
    build_gtin14([resolve_indicator(indicator, 0), 9, 7, 8] ++ code)
  end

  defp normalize_gtin(gtin, "GTIN-12", indicator) do
    digits = String.codepoints(gtin) |> Enum.map(&String.to_integer/1)
    {code, _} = Enum.split(digits, 11)
    build_gtin14([resolve_indicator(indicator, 1), 0] ++ code)
  end

  defp normalize_gtin(gtin, "GTIN-13", indicator) do
    digits = String.codepoints(gtin) |> Enum.map(&String.to_integer/1)
    {code, _} = Enum.split(digits, 12)
    build_gtin14([resolve_indicator(indicator, 1)] ++ code)
  end

  defp normalize_gtin(gtin, "GTIN-14", _indicator), do: gtin

  # Resolves the `:default` sentinel to the per-type default leading digit,
  # while passing an explicitly supplied indicator through unchanged.
  defp resolve_indicator(:default, type_default), do: type_default
  defp resolve_indicator(indicator, _type_default), do: indicator

  # Builds a GTIN-14 string from a 13-digit body (indicator + 12 data digits),
  # appending a freshly computed mod-10 check digit over the full body.
  defp build_gtin14(body) do
    "#{Enum.join(body)}#{generate_check_digit(body)}"
  end

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
  Expands a UPC-E code into its full 12-digit UPC-A form.

  Delegates to `ExGtin.Convert.UPC.upce_to_upca/1`. Returns `{:ok, upca}` on
  success or `{:error, reason}` on failure.

  ## Examples

      iex> ExGtin.upce_to_upca("01234565")
      {:ok, "012345000065"}

      iex> ExGtin.upce_to_upca("21234560")
      {:error, "UPC-E number system must be 0 or 1"}
  """
  @doc since: "1.4.0"
  @spec upce_to_upca(String.t() | integer | list(0..9)) :: result
  def upce_to_upca(upce), do: UPC.upce_to_upca(upce)

  @doc """
  Expands a UPC-E code into its full 12-digit UPC-A form.

  Throws `ArgumentError` if an error occurs.

  ## Examples

      iex> ExGtin.upce_to_upca!("01234565")
      "012345000065"
  """
  @doc since: "1.4.0"
  @spec upce_to_upca!(String.t() | integer | list(0..9)) :: String.t()
  def upce_to_upca!(upce) do
    case UPC.upce_to_upca(upce) do
      {:ok, result} -> result
      {:error, reason} -> raise ArgumentError, message: reason
    end
  end

  @doc """
  Compresses a full 12-digit UPC-A into its 8-digit UPC-E form.

  Delegates to `ExGtin.Convert.UPC.upca_to_upce/1`. Returns `{:ok, upce}` when a
  compression rule matches or `{:error, reason}` otherwise.

  ## Examples

      iex> ExGtin.upca_to_upce("012345000065")
      {:ok, "01234565"}

      iex> ExGtin.upca_to_upce("012345678905")
      {:error, "UPC-A is not compressible to UPC-E"}
  """
  @doc since: "1.4.0"
  @spec upca_to_upce(String.t() | integer | list(0..9)) :: result
  def upca_to_upce(upca), do: UPC.upca_to_upce(upca)

  @doc """
  Compresses a full 12-digit UPC-A into its 8-digit UPC-E form.

  Throws `ArgumentError` if an error occurs.

  ## Examples

      iex> ExGtin.upca_to_upce!("012345000065")
      "01234565"
  """
  @doc since: "1.4.0"
  @spec upca_to_upce!(String.t() | integer | list(0..9)) :: String.t()
  def upca_to_upce!(upca) do
    case UPC.upca_to_upce(upca) do
      {:ok, result} -> result
      {:error, reason} -> raise ArgumentError, message: reason
    end
  end

  @doc """
  Reduces a GTIN-14 with indicator `0` to its base GTIN-13.

  Delegates to `ExGtin.Convert.GTIN14.to_gtin13/1`. Returns `{:ok, gtin13}` on
  success or `{:error, reason}` on failure (for example when the indicator is
  not `0` or the input is not a valid GTIN-14).

  ## Examples

      iex> ExGtin.to_gtin13("06291041500213")
      {:ok, "6291041500213"}

      iex> ExGtin.to_gtin13("16291041500210")
      {:error, "GTIN-14 indicator is not 0; no base GTIN-13"}
  """
  @doc since: "1.4.0"
  @spec to_gtin13(String.t() | integer | list(0..9)) :: result
  def to_gtin13(gtin14), do: GTIN14.to_gtin13(gtin14)

  @doc """
  Reduces a GTIN-14 with indicator `0` to its base GTIN-13.

  Throws `ArgumentError` if an error occurs.

  ## Examples

      iex> ExGtin.to_gtin13!("06291041500213")
      "6291041500213"
  """
  @doc since: "1.4.0"
  @spec to_gtin13!(String.t() | integer | list(0..9)) :: String.t()
  def to_gtin13!(gtin14) do
    case GTIN14.to_gtin13(gtin14) do
      {:ok, result} -> result
      {:error, reason} -> raise ArgumentError, message: reason
    end
  end

  @doc """
  Reduces a GTIN-14 with indicator `0` to its base GTIN-12.

  Delegates to `ExGtin.Convert.GTIN14.to_gtin12/1`. Returns `{:ok, gtin12}` on
  success or `{:error, reason}` on failure (for example when the indicator is
  not `0`, no base GTIN-12 exists, or the input is not a valid GTIN-14).

  ## Examples

      iex> ExGtin.to_gtin12("00012345000010")
      {:ok, "012345000010"}

      iex> ExGtin.to_gtin12("16291041500210")
      {:error, "GTIN-14 indicator is not 0; no base GTIN-13"}
  """
  @doc since: "1.4.0"
  @spec to_gtin12(String.t() | integer | list(0..9)) :: result
  def to_gtin12(gtin14), do: GTIN14.to_gtin12(gtin14)

  @doc """
  Reduces a GTIN-14 with indicator `0` to its base GTIN-12.

  Throws `ArgumentError` if an error occurs.

  ## Examples

      iex> ExGtin.to_gtin12!("00012345000010")
      "012345000010"
  """
  @doc since: "1.4.0"
  @spec to_gtin12!(String.t() | integer | list(0..9)) :: String.t()
  def to_gtin12!(gtin14) do
    case GTIN14.to_gtin12(gtin14) do
      {:ok, result} -> result
      {:error, reason} -> raise ArgumentError, message: reason
    end
  end

  @doc """
  Decomposes a GTIN-8/12/13/14 into its structured components.

  Delegates to `ExGtin.Parse.parse/1`. Returns `{:ok, parsed}` for a well-formed
  code, where `parsed` is a `t:ExGtin.Parse.parsed/0` map exposing `type`,
  `digits`, `indicator`, `gs1_prefix`, `gs1_prefix_region`, `check_digit`, and
  `valid?`. A tampered check digit yields `valid?: false` rather than an error;
  an `{:error, _}` tuple is returned only when the input is not a valid code
  (wrong length or non-digit characters).

  No company/item split is performed: `parse/1` does **not** divide the body
  into a GS1 company prefix and an item reference, because the company-prefix
  length is assigned per company and is not derivable from the number offline.

  ## Examples

      iex> ExGtin.parse("6291041500213")
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

      iex> {:ok, %{valid?: false}} = ExGtin.parse("6291041500214")
      iex> :ok
      :ok
  """
  @doc since: "1.4.0"
  @spec parse(String.t() | integer | list(0..9)) ::
          {:ok, ExGtin.Parse.parsed()} | {:error, String.t()}
  def parse(code), do: ExGtin.Parse.parse(code)

  @doc """
  Validates an 18-digit SSCC (Serial Shipping Container Code).

  Delegates to `ExGtin.Keys.validate_sscc/1`. Returns `{:ok, "SSCC"}` when the
  input is exactly 18 digits with a correct mod-10 check digit, or
  `{:error, reason}` otherwise.

  ## Examples

      iex> ExGtin.validate_sscc("106141412345678908")
      {:ok, "SSCC"}

      iex> ExGtin.validate_sscc("106141412345678909")
      {:error, "Invalid Code"}
  """
  @doc since: "1.4.0"
  @spec validate_sscc(String.t() | integer | list(0..9)) :: result
  def validate_sscc(sscc), do: ExGtin.Keys.validate_sscc(sscc)

  @doc """
  Validates an 18-digit SSCC (Serial Shipping Container Code).

  Throws `ArgumentError` if an error occurs.

  ## Examples

      iex> ExGtin.validate_sscc!("106141412345678908")
      "SSCC"
  """
  @doc since: "1.4.0"
  @spec validate_sscc!(String.t() | integer | list(0..9)) :: String.t()
  def validate_sscc!(sscc) do
    case ExGtin.Keys.validate_sscc(sscc) do
      {:ok, result} -> result
      {:error, reason} -> raise ArgumentError, message: reason
    end
  end

  @doc """
  Generates a complete 18-digit SSCC from a 17-digit body.

  Delegates to `ExGtin.Keys.generate_sscc/1`. Returns `{:ok, sscc}` with the
  computed check digit appended, or `{:error, reason}` when the body is not
  exactly 17 digits or contains non-digit content.

  ## Examples

      iex> ExGtin.generate_sscc("10614141234567890")
      {:ok, "106141412345678908"}
  """
  @doc since: "1.4.0"
  @spec generate_sscc(String.t() | integer | list(0..9)) :: result
  def generate_sscc(body), do: ExGtin.Keys.generate_sscc(body)

  @doc """
  Generates a complete 18-digit SSCC from a 17-digit body.

  Throws `ArgumentError` if an error occurs.

  ## Examples

      iex> ExGtin.generate_sscc!("10614141234567890")
      "106141412345678908"
  """
  @doc since: "1.4.0"
  @spec generate_sscc!(String.t() | integer | list(0..9)) :: String.t()
  def generate_sscc!(body) do
    case ExGtin.Keys.generate_sscc(body) do
      {:ok, result} -> result
      {:error, reason} -> raise ArgumentError, message: reason
    end
  end

  @doc """
  Validates a 17-digit GSIN (Global Shipment Identification Number).

  Delegates to `ExGtin.Keys.validate_gsin/1`. Returns `{:ok, "GSIN"}` when the
  input is exactly 17 digits with a correct mod-10 check digit, or
  `{:error, reason}` otherwise.

  ## Examples

      iex> ExGtin.validate_gsin("10614141234567894")
      {:ok, "GSIN"}

      iex> ExGtin.validate_gsin("10614141234567895")
      {:error, "Invalid Code"}
  """
  @doc since: "1.4.0"
  @spec validate_gsin(String.t() | integer | list(0..9)) :: result
  def validate_gsin(gsin), do: ExGtin.Keys.validate_gsin(gsin)

  @doc """
  Validates a 17-digit GSIN (Global Shipment Identification Number).

  Throws `ArgumentError` if an error occurs.

  ## Examples

      iex> ExGtin.validate_gsin!("10614141234567894")
      "GSIN"
  """
  @doc since: "1.4.0"
  @spec validate_gsin!(String.t() | integer | list(0..9)) :: String.t()
  def validate_gsin!(gsin) do
    case ExGtin.Keys.validate_gsin(gsin) do
      {:ok, result} -> result
      {:error, reason} -> raise ArgumentError, message: reason
    end
  end

  @doc """
  Generates a complete 17-digit GSIN from a 16-digit body.

  Delegates to `ExGtin.Keys.generate_gsin/1`. Returns `{:ok, gsin}` with the
  computed check digit appended, or `{:error, reason}` when the body is not
  exactly 16 digits or contains non-digit content.

  ## Examples

      iex> ExGtin.generate_gsin("1061414123456789")
      {:ok, "10614141234567894"}
  """
  @doc since: "1.4.0"
  @spec generate_gsin(String.t() | integer | list(0..9)) :: result
  def generate_gsin(body), do: ExGtin.Keys.generate_gsin(body)

  @doc """
  Generates a complete 17-digit GSIN from a 16-digit body.

  Throws `ArgumentError` if an error occurs.

  ## Examples

      iex> ExGtin.generate_gsin!("1061414123456789")
      "10614141234567894"
  """
  @doc since: "1.4.0"
  @spec generate_gsin!(String.t() | integer | list(0..9)) :: String.t()
  def generate_gsin!(body) do
    case ExGtin.Keys.generate_gsin(body) do
      {:ok, result} -> result
      {:error, reason} -> raise ArgumentError, message: reason
    end
  end

  @doc """
  Converts a valid ISBN-10 into its ISBN-13 (`978`-prefixed) equivalent.

  Delegates to `ExGtin.Convert.Bookland.isbn10_to_isbn13/1`. Returns
  `{:ok, isbn13}` on success or `{:error, "Invalid ISBN-10"}` when the input is
  not a valid ISBN-10.

  ## Examples

      iex> ExGtin.isbn10_to_isbn13("0306406152")
      {:ok, "9780306406157"}

      iex> ExGtin.isbn10_to_isbn13("1234567890")
      {:error, "Invalid ISBN-10"}
  """
  @doc since: "1.4.0"
  @spec isbn10_to_isbn13(String.t() | integer | list(0..9)) :: result
  def isbn10_to_isbn13(isbn10), do: Bookland.isbn10_to_isbn13(isbn10)

  @doc """
  Converts a `978`-prefixed ISBN-13 back into its ISBN-10 equivalent.

  Delegates to `ExGtin.Convert.Bookland.isbn13_to_isbn10/1`. Returns
  `{:ok, isbn10}` on success, `{:error, "ISBN-13 with 979 prefix has no ISBN-10
  equivalent"}` for a `979`-prefixed code, or `{:error, "Invalid ISBN-13"}` for
  any other invalid input.

  ## Examples

      iex> ExGtin.isbn13_to_isbn10("9780306406157")
      {:ok, "0306406152"}

      iex> ExGtin.isbn13_to_isbn10("9791234567896")
      {:error, "ISBN-13 with 979 prefix has no ISBN-10 equivalent"}
  """
  @doc since: "1.4.0"
  @spec isbn13_to_isbn10(String.t() | integer | list(0..9)) :: result
  def isbn13_to_isbn10(isbn13), do: Bookland.isbn13_to_isbn10(isbn13)

  @doc """
  Validates an ISBN by dispatching on its length.

  Delegates to `ExGtin.Convert.Bookland.valid_isbn?/1`. A 10-character input is
  validated with the ISBN-10 mod-11 check (trailing `X` allowed) and a 13-digit
  input as an ISBN-13 (`978`/`979` prefix with a valid GS1 mod-10 check). Any
  other length is invalid.

  Returns a `boolean`.

  ## Examples

      iex> ExGtin.valid_isbn?("9780306406157")
      true

      iex> ExGtin.valid_isbn?("1234567890")
      false
  """
  @doc since: "1.4.0"
  @spec valid_isbn?(String.t() | integer | list(0..9)) :: boolean
  def valid_isbn?(isbn), do: Bookland.valid_isbn?(isbn)

  @doc """
  Validates a GS1 identifier key by kind.

  Delegates to `ExGtin.Keys.validate_key/2`. `code` may be a `String`, integer,
  or digit list, and `key` names which key to check against (see
  `t:ExGtin.Keys.gs1_key/0`). Returns `{:ok, key}` (the key atom) on success, or
  an `{:error, reason}` tuple such as `{:error, "Invalid Code"}`,
  `{:error, "Invalid GRAI"}`/`"Invalid GIAI"`/`"Invalid GDTI"`, or
  `{:error, "Unsupported key"}`.

  ## Examples

      iex> ExGtin.validate_key("4012345000009", :gln)
      {:ok, :gln}

      iex> ExGtin.validate_key("00614141543212", :grai)
      {:ok, :grai}

      iex> ExGtin.validate_key("4000001111", :giai)
      {:ok, :giai}

      iex> ExGtin.validate_key("4012345000008", :gln)
      {:error, "Invalid Code"}
  """
  @doc since: "1.4.0"
  @spec validate_key(String.t() | integer | list(0..9), ExGtin.Keys.gs1_key()) ::
          {:ok, ExGtin.Keys.gs1_key()} | {:error, String.t()}
  def validate_key(code, key), do: ExGtin.Keys.validate_key(code, key)

  @doc """
  Generates a complete fixed-length GS1 key from its body.

  Delegates to `ExGtin.Keys.generate_key/2`. Takes `body` — the key without its
  trailing check digit — as a `String`, integer, or digit list, computes the
  mod-10 check digit, and returns `{:ok, code}` with the check digit appended.
  Only the fixed-length keys can be generated; the variable-component keys
  `:grai` and `:giai` return `{:error, "Unsupported key"}`, and an
  `{:error, reason}` tuple is returned for a wrong-length or non-digit body.

  ## Examples

      iex> ExGtin.generate_key("401234500000", :gln)
      {:ok, "4012345000009"}

      iex> ExGtin.generate_key("12345", :gln)
      {:error, "Invalid Code"}

      iex> ExGtin.generate_key("00000000", :giai)
      {:error, "Unsupported key"}
  """
  @doc since: "1.4.0"
  @spec generate_key(String.t() | integer | list(0..9), ExGtin.Keys.gs1_key()) :: result
  def generate_key(body, key), do: ExGtin.Keys.generate_key(body, key)

  @doc """
  Validates a list of codes, pairing each input with its `validate/1` result.

  Delegates to `ExGtin.Batch.validate_all/1`. Maps each element of `codes` to a
  `{input, result}` tuple, preserving list order. Individual items never raise
  and an empty list returns an empty list.

  ## Examples

      iex> ExGtin.validate_all(["6291041500213", "6291041500214"])
      [
        {"6291041500213", {:ok, "GTIN-13"}},
        {"6291041500214", {:error, "Invalid Code"}}
      ]
  """
  @doc since: "1.4.0"
  @spec validate_all([String.t()]) :: [{String.t(), result}]
  def validate_all(codes), do: ExGtin.Batch.validate_all(codes)

  @doc """
  Partitions a list of codes into valid and invalid buckets.

  Delegates to `ExGtin.Batch.partition/1`. Returns a map with `:valid` (inputs
  that produced `{:ok, _}`) and `:invalid` (inputs that produced `{:error, _}`),
  preserving order within each bucket. Individual items never raise and an empty
  list returns empty buckets.

  ## Examples

      iex> ExGtin.partition(["6291041500213", "6291041500214"])
      %{valid: ["6291041500213"], invalid: ["6291041500214"]}
  """
  @doc since: "1.4.0"
  @spec partition([String.t()]) :: %{valid: [String.t()], invalid: [String.t()]}
  def partition(codes), do: ExGtin.Batch.partition(codes)

  @doc """
  Find the GS1 prefix country for a GTIN number

  This is the preferred public entry point for prefix lookups; it delegates to
  `ExGtin.Validation.find_gs1_prefix_country/1`. Note that GTIN-8 inputs use
  GTIN-13 prefix-table semantics and can be misleading (see that function's
  deprecation note); GTIN-12/13/14 lookups are unaffected.

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

  @doc """
  Parses a GS1-128 / Application Identifier (AI) element string.

  A single entry point that accepts **both** serializations of the same logical
  payload and dispatches to the matching parser:

    * the **parenthesized** human-readable form, `(01)06291041500213(10)ABC123`,
      recognized because the payload starts with `(`; and
    * the **raw FNC1** scanner form, where fixed-length AIs are concatenated
      without a separator and variable-length AIs are terminated by the FNC1/GS
      separator (`<GS>`, ASCII 29) or the end of the payload.

  Any payload that does not start with `(` is treated as the raw FNC1 form.
  Delegates to `ExGtin.GS1.ElementString`; both forms of the same payload produce
  an equal `%{ai => value}` map. Returns `{:ok, map}` on success or
  `{:error, reason}` on failure (unknown AI, wrong fixed-length value, unbalanced
  parentheses, or an invalid embedded GTIN — see
  `t:ExGtin.GS1.ElementString.error/0`).

  The initially supported AI set is 01, 10, 11, 13, 15, 17, 21, and the 3xx
  weight AIs; an AI outside that set produces an `{:error, {:unknown_ai, _, _}}`
  tuple. Date-format AIs (11/13/15/17) are surfaced as their raw `YYMMDD` string;
  see `parse_gs1/2` to opt into interpreting them into Elixir `Date` structs.

  ## Partial parses

  When a leading portion of the payload parses but the remainder cannot be
  interpreted (an unknown AI, or leftover bytes that do not form a known AI code)
  after at least one AI+value pair has been read, the unparsed remainder is
  reported as a 3-tuple `{:ok, map, unparsed}` rather than dropped. A payload
  that is uninterpretable from the very start is still an `{:error, _}`; see the
  "Partial parses and the unparsed remainder" section of
  `ExGtin.GS1.ElementString` for the full rules.

  ## Examples

  The parenthesized form (starts with `(`):

      iex> ExGtin.parse_gs1("(01)06291041500213(17)261231(10)ABC123")
      {:ok, %{"01" => "06291041500213", "17" => "261231", "10" => "ABC123"}}

  The raw FNC1 form of the same payload parses through the same entry point:

      iex> ExGtin.parse_gs1("010629104150021310ABC123" <> <<29>> <> "21XYZ789")
      {:ok, %{"01" => "06291041500213", "10" => "ABC123", "21" => "XYZ789"}}

  A payload whose leading AIs parse but whose tail is an unknown AI reports the
  unparsed remainder instead of dropping it:

      iex> ExGtin.parse_gs1("(01)06291041500213(99)ABC")
      {:ok, %{"01" => "06291041500213"}, "(99)ABC"}

  An unsupported AI at the very start (nothing parsed yet) errors with the
  offending code and its position:

      iex> ExGtin.parse_gs1("(99)ABC")
      {:error, {:unknown_ai, "99", 0}}
  """
  @doc since: "1.5.0"
  @spec parse_gs1(String.t()) :: ExGtin.GS1.ElementString.result()
  def parse_gs1(payload), do: parse_gs1(payload, [])

  @doc """
  Parses a GS1-128 / AI element string with parser options.

  Behaves exactly like `parse_gs1/1`, dispatching on the leading `(` to the
  parenthesized or raw FNC1 parser, but forwards `opts` to
  `ExGtin.GS1.ElementString`. The primary documented option is `:dates`:

    * `dates: :raw` (the default) keeps date-format AI values (11/13/15/17) as the
      raw `YYMMDD` string; and
    * `dates: :parsed` interprets them into Elixir `Date` structs.

  ## Examples

      iex> ExGtin.parse_gs1("(01)06291041500213(17)261231", dates: :parsed)
      {:ok, %{"01" => "06291041500213", "17" => ~D[2026-12-31]}}
  """
  @doc since: "1.5.0"
  @spec parse_gs1(String.t(), ExGtin.GS1.ElementString.options()) ::
          ExGtin.GS1.ElementString.result()
  def parse_gs1("(" <> _rest = payload, opts),
    do: ElementString.parse_parenthesized(payload, opts)

  def parse_gs1(payload, opts), do: ElementString.parse_raw(payload, opts)

  @doc """
  Parses a GS1-128 / AI element string, raising on error.

  The raising counterpart of `parse_gs1/1`: returns the parsed `%{ai => value}`
  map directly on a full parse, or raises `ArgumentError` on any parse error.
  Because element-string errors are structured tuples (see
  `t:ExGtin.GS1.ElementString.error/0`) rather than strings, the reason is
  formatted into the exception message with `inspect/1`.

  A **partial parse does not raise**: parsing itself succeeded for the leading
  portion, so `parse_gs1!/1` returns a `{map, unparsed}` tuple carrying the
  parsed map and the uninterpretable trailing remainder, rather than raising and
  discarding the remainder. Only a hard `{:error, _}` (including a payload that
  is uninterpretable from the very start) raises.

  ## Examples

      iex> ExGtin.parse_gs1!("(01)06291041500213(10)ABC123")
      %{"01" => "06291041500213", "10" => "ABC123"}

  A partial parse returns the parsed map paired with the unparsed remainder
  instead of raising:

      iex> ExGtin.parse_gs1!("(01)06291041500213(99)ABC")
      {%{"01" => "06291041500213"}, "(99)ABC"}

      iex> ExGtin.parse_gs1!("(99)ABC")
      ** (ArgumentError) {:unknown_ai, "99", 0}
  """
  @doc since: "1.5.0"
  @spec parse_gs1!(String.t()) ::
          ExGtin.GS1.ElementString.parsed()
          | {ExGtin.GS1.ElementString.parsed(), unparsed :: String.t()}
  def parse_gs1!(payload) do
    case parse_gs1(payload) do
      {:ok, result} -> result
      {:ok, result, unparsed} -> {result, unparsed}
      {:error, reason} -> raise ArgumentError, message: inspect(reason)
    end
  end

  @doc """
  Decodes a restricted-circulation number's embedded price/weight against a scheme.

  A single public entry point for RCN decoding that delegates to
  `ExGtin.RCN.decode/2`. `code` is a GTIN-13 digit string, non-negative integer,
  or digit list, and `scheme` is either a shipped scheme's named atom (resolved
  via `ExGtin.RCN.Schemes.fetch/1`) or an explicit
  `t:ExGtin.RCN.Schemes.rcn_scheme/0` scheme map, so callers can use a documented
  default or supply their own market layout.

  On success returns `{:ok, t:ExGtin.RCN.rcn_parsed/0}` — a map with the extracted
  `item` reference and an `embedded` map carrying the raw digit substring under
  `:price` or `:weight`, per the scheme's `embedded` tag. Both values are raw
  digit strings (leading zeros preserved, no implied-decimal scaling applied);
  callers apply any scaling their market needs. Returns `{:error, reason}` when
  the code is the wrong length, is not a digit sequence, does not match the
  scheme's prefix, names an unknown scheme, or fails the scheme's internal
  price/weight check digit.

  ## Examples

  A named scheme with an internal price check digit:

      iex> ExGtin.parse_rcn("2123451789012", :gs1_germany_price)
      {:ok, %{item: "12345", embedded: %{price: "78901"}}}

  An explicit scheme map:

      iex> scheme = %{prefix: ["2"], item: 2..6, embedded: {:price, 8..12}, check: nil}
      iex> ExGtin.parse_rcn("2123456789012", scheme)
      {:ok, %{item: "12345", embedded: %{price: "78901"}}}

  An unknown scheme errors:

      iex> ExGtin.parse_rcn("2123456789012", :no_such_scheme)
      {:error, "Unknown RCN scheme: :no_such_scheme"}
  """
  @doc since: "1.5.0"
  @spec parse_rcn(RCN.code(), RCN.scheme()) ::
          {:ok, RCN.rcn_parsed()} | {:error, String.t()}
  def parse_rcn(code, scheme), do: RCN.decode(code, scheme)

  @doc """
  Decodes a restricted-circulation number against a scheme, raising on error.

  The raising counterpart of `parse_rcn/2`: returns the
  `t:ExGtin.RCN.rcn_parsed/0` map directly on success, or raises `ArgumentError`
  with the failure reason as its message. RCN errors are plain strings, so the
  reason is used as the exception message directly.

  ## Examples

      iex> ExGtin.parse_rcn!("2123451789012", :gs1_germany_price)
      %{item: "12345", embedded: %{price: "78901"}}
  """
  @doc since: "1.5.0"
  @spec parse_rcn!(RCN.code(), RCN.scheme()) :: RCN.rcn_parsed()
  def parse_rcn!(code, scheme) do
    case RCN.decode(code, scheme) do
      {:ok, result} -> result
      {:error, reason} -> raise ArgumentError, message: reason
    end
  end

  @doc """
  Corrects a nearly-valid GTIN, inferring the target length.

  Delegates to `ExGtin.Fix.fix/1`. Trims surrounding whitespace and left-pads
  with zeros to the smallest supported GTIN length (8, 12, 13, 14) the trimmed
  digits fit into, then re-validates the check digit. It repairs only the
  information-preserving damage of dropped leading zeros and stray whitespace;
  it never alters a significant digit or the check digit.

  Returns `{:ok, corrected}` or `{:error, reason}`, where `reason` is one of the
  `t:ExGtin.Fix.reason/0` atoms (`:non_numeric`, `:too_long`, `:invalid_length`,
  `:check_digit_incorrect`).

  ## Examples

      iex> ExGtin.fix("87248795257")
      {:ok, "087248795257"}

      iex> ExGtin.fix(" 6291041500213 ")
      {:ok, "6291041500213"}

      iex> ExGtin.fix("123456789013")
      {:error, :check_digit_incorrect}
  """
  @doc since: "1.6.0"
  @spec fix(String.t() | integer | list(0..9)) :: {:ok, String.t()} | {:error, Fix.reason()}
  def fix(code), do: Fix.fix(code)

  @doc """
  Corrects a nearly-valid GTIN to a specific target length.

  Delegates to `ExGtin.Fix.fix/2`. `target` is a supported length integer
  (`8`, `12`, `13`, `14`) or its named atom (`:gtin8`, `:gtin12`, `:gtin13`,
  `:gtin14`). Trims whitespace, left-pads with zeros to `target`, then
  re-validates the check digit.

  Returns `{:ok, corrected}` or `{:error, reason}` (see `t:ExGtin.Fix.reason/0`).

  ## Examples

      iex> ExGtin.fix("495205944325", 13)
      {:ok, "0495205944325"}

      iex> ExGtin.fix("0000000000000", 12)
      {:error, :too_long}
  """
  @doc since: "1.6.0"
  @spec fix(String.t() | integer | list(0..9), Fix.target()) ::
          {:ok, String.t()} | {:error, Fix.reason()}
  def fix(code, target), do: Fix.fix(code, target)

  @doc """
  The raising variant of `fix/1`.

  Delegates to `ExGtin.Fix.fix!/1`. Returns the corrected string or raises
  `ArgumentError` with the failure reason as its message.

  ## Examples

      iex> ExGtin.fix!("87248795257")
      "087248795257"
  """
  @doc since: "1.6.0"
  @spec fix!(String.t() | integer | list(0..9)) :: String.t()
  def fix!(code), do: Fix.fix!(code)

  @doc """
  The raising variant of `fix/2`.

  Delegates to `ExGtin.Fix.fix!/2`. Returns the corrected string or raises
  `ArgumentError` with the failure reason as its message.

  ## Examples

      iex> ExGtin.fix!("495205944325", 13)
      "0495205944325"
  """
  @doc since: "1.6.0"
  @spec fix!(String.t() | integer | list(0..9), Fix.target()) :: String.t()
  def fix!(code, target), do: Fix.fix!(code, target)
end
