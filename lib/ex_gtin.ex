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
