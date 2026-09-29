defmodule ExGtin.KeysTest do
  @moduledoc """
  Tests for SSCC (Serial Shipping Container Code) and GSIN (Global Shipment
  Identification Number) validation and generation (`ExGtin.Keys`) and their
  public wiring on `ExGtin`.

  SSCC: an 18-digit SSCC with a valid mod-10 check digit yields
  `{:ok, "SSCC"}`; an 18-digit value with a wrong check digit yields
  `{:error, "Invalid Code"}`; a 17-digit body generates a complete SSCC with the
  check digit appended; any wrong-length input returns an `{:error, _}` tuple; an
  SSCC is never classified as a GTIN-14 and a GTIN-14 is never classified as an
  SSCC, because key detection is explicit; and the round-trip
  `validate_sscc(generate_sscc(body)) == {:ok, "SSCC"}` holds.

  GSIN: a 17-digit GSIN with a valid mod-10 check digit yields
  `{:ok, "GSIN"}`; a 16-digit body generates a complete GSIN with the check
  digit appended; any wrong-length input returns an `{:error, _}` tuple; a GSIN
  is never classified as another key of a nearby length — a 17-digit GSIN is
  rejected by the 18-digit `validate_sscc` and is not read as a GTIN, and an
  18-digit SSCC is rejected by `validate_gsin`; and the round-trip
  `validate_gsin(generate_gsin(body)) == {:ok, "GSIN"}` holds.

  SSCC and GSIN check digits are computed against the real `ExGtin.CheckDigit`
  engine (via generation) rather than hand-invented, so the assertions pin
  actual behavior end to end.
  """
  use ExUnit.Case

  doctest ExGtin.Keys

  alias ExGtin.Keys

  # A representative valid SSCC and its 17-digit body, confirmed against the
  # check-digit engine (generate_sscc/1 appends 8 to this body).
  @sscc_body "10614141234567890"
  @sscc "106141412345678908"

  # A representative valid GSIN and its 16-digit body, confirmed against the
  # check-digit engine (generate_gsin/1 appends 4 to this body).
  @gsin_body "1061414123456789"
  @gsin "10614141234567894"

  describe "valid SSCC checksum yields {:ok, \"SSCC\"}" do
    test "an 18-digit SSCC with a correct check digit validates" do
      assert Keys.validate_sscc(@sscc) == {:ok, "SSCC"}
    end

    test "additional engine-computed SSCCs validate" do
      for body <- ["00000000000000000", "12345678901234567", "99999999999999999"] do
        assert {:ok, sscc} = Keys.generate_sscc(body)
        assert Keys.validate_sscc(sscc) == {:ok, "SSCC"}
      end
    end

    test "String, integer, and digit-list inputs agree for a valid SSCC" do
      digits = String.codepoints(@sscc) |> Enum.map(&String.to_integer/1)

      assert Keys.validate_sscc(@sscc) == {:ok, "SSCC"}
      assert Keys.validate_sscc(digits) == {:ok, "SSCC"}
      # integer input drops the (non-leading-zero) form losslessly here
      assert Keys.validate_sscc(String.to_integer(@sscc)) == {:ok, "SSCC"}
    end
  end

  describe "invalid checksum yields an error" do
    test "an 18-digit value with a wrong check digit is rejected" do
      # @sscc ends in 8; 9 is the wrong check digit for the same body.
      assert Keys.validate_sscc("106141412345678909") == {:error, "Invalid Code"}
    end

    test "every wrong final digit for a known body is rejected" do
      {:ok, sscc} = Keys.generate_sscc(@sscc_body)
      {body, [correct]} = Enum.split(String.codepoints(sscc), 17)
      body = Enum.join(body)

      for wrong <- 0..9, Integer.to_string(wrong) != correct do
        assert Keys.validate_sscc(body <> Integer.to_string(wrong)) ==
                 {:error, "Invalid Code"}
      end
    end
  end

  describe "wrong length yields an error" do
    test "shorter-than-18 input is rejected" do
      assert {:error, _} = Keys.validate_sscc("12345")
      assert {:error, _} = Keys.validate_sscc(@sscc_body)
    end

    test "longer-than-18 input is rejected" do
      assert {:error, _} = Keys.validate_sscc(@sscc <> "0")
    end

    test "non-digit content is rejected" do
      assert {:error, _} = Keys.validate_sscc("10614141234567890a")
    end
  end

  describe "generation appends the check digit" do
    test "a 17-digit body yields an 18-digit SSCC" do
      assert {:ok, sscc} = Keys.generate_sscc(@sscc_body)
      assert String.length(sscc) == 18
      assert String.starts_with?(sscc, @sscc_body)
    end

    test "a wrong-length body is rejected" do
      assert {:error, _} = Keys.generate_sscc("1234")
      assert {:error, _} = Keys.generate_sscc(@sscc)
    end
  end

  describe "no GTIN-14 collision; key detection is explicit" do
    test "an 18-digit SSCC is not misread as a GTIN by validate/1" do
      # A valid SSCC is 18 digits, which is not a GTIN length; validate/1 must
      # not classify it as any GTIN type.
      assert {:ok, "SSCC"} = Keys.validate_sscc(@sscc)
      assert {:error, _} = ExGtin.validate(@sscc)
    end

    test "validate_sscc rejects a valid 14-digit GTIN" do
      # 10614141000415 is a valid GTIN-14, but it is the wrong length for an
      # SSCC and must be rejected rather than accepted as an SSCC.
      assert ExGtin.validate("10614141000415") == {:ok, "GTIN-14"}
      assert {:error, _} = Keys.validate_sscc("10614141000415")
    end
  end

  describe "round-trip validate_sscc(generate_sscc(body)) == {:ok, \"SSCC\"}" do
    for body <- [
          "10614141234567890",
          "00000000000000000",
          "12345678901234567",
          "99999999999999999",
          "34567890123456789"
        ] do
      test "body #{body} round-trips through generate then validate" do
        assert {:ok, sscc} = Keys.generate_sscc(unquote(body))
        assert Keys.validate_sscc(sscc) == {:ok, "SSCC"}
      end
    end
  end

  describe "valid GSIN checksum yields {:ok, \"GSIN\"}" do
    test "a 17-digit GSIN with a correct check digit validates" do
      assert Keys.validate_gsin(@gsin) == {:ok, "GSIN"}
    end

    test "additional engine-computed GSINs validate" do
      for body <- ["0000000000000000", "1234567890123456", "9999999999999999"] do
        assert {:ok, gsin} = Keys.generate_gsin(body)
        assert Keys.validate_gsin(gsin) == {:ok, "GSIN"}
      end
    end

    test "String, integer, and digit-list inputs agree for a valid GSIN" do
      digits = String.codepoints(@gsin) |> Enum.map(&String.to_integer/1)

      assert Keys.validate_gsin(@gsin) == {:ok, "GSIN"}
      assert Keys.validate_gsin(digits) == {:ok, "GSIN"}
      # integer input drops the (non-leading-zero) form losslessly here
      assert Keys.validate_gsin(String.to_integer(@gsin)) == {:ok, "GSIN"}
    end
  end

  describe "invalid GSIN checksum yields an error" do
    test "a 17-digit value with a wrong check digit is rejected" do
      # @gsin ends in 4; 5 is the wrong check digit for the same body.
      assert Keys.validate_gsin("10614141234567895") == {:error, "Invalid Code"}
    end

    test "every wrong final digit for a known body is rejected" do
      {:ok, gsin} = Keys.generate_gsin(@gsin_body)
      {body, [correct]} = Enum.split(String.codepoints(gsin), 16)
      body = Enum.join(body)

      for wrong <- 0..9, Integer.to_string(wrong) != correct do
        assert Keys.validate_gsin(body <> Integer.to_string(wrong)) ==
                 {:error, "Invalid Code"}
      end
    end
  end

  describe "wrong GSIN length yields an error" do
    test "shorter-than-17 input is rejected" do
      assert {:error, _} = Keys.validate_gsin("12345")
      assert {:error, _} = Keys.validate_gsin(@gsin_body)
    end

    test "longer-than-17 input is rejected" do
      assert {:error, _} = Keys.validate_gsin(@gsin <> "0")
    end

    test "non-digit content is rejected" do
      assert {:error, _} = Keys.validate_gsin("1061414123456789a")
    end
  end

  describe "GSIN generation appends the check digit" do
    test "a 16-digit body yields a 17-digit GSIN" do
      assert {:ok, gsin} = Keys.generate_gsin(@gsin_body)
      assert String.length(gsin) == 17
      assert String.starts_with?(gsin, @gsin_body)
    end

    test "a wrong-length body is rejected" do
      assert {:error, _} = Keys.generate_gsin("1234")
      assert {:error, _} = Keys.generate_gsin(@gsin)
    end
  end

  describe "no cross-key collision; key detection is explicit" do
    test "a 17-digit GSIN is not accepted by the 18-digit validate_sscc" do
      assert {:ok, "GSIN"} = Keys.validate_gsin(@gsin)
      assert {:error, _} = Keys.validate_sscc(@gsin)
    end

    test "a 17-digit GSIN is not misread as a GTIN by validate/1" do
      # 17 digits is not a GTIN length; validate/1 must not classify it.
      assert {:ok, "GSIN"} = Keys.validate_gsin(@gsin)
      assert {:error, _} = ExGtin.validate(@gsin)
    end

    test "an 18-digit SSCC is not accepted by the 17-digit validate_gsin" do
      assert {:ok, "SSCC"} = Keys.validate_sscc(@sscc)
      assert {:error, _} = Keys.validate_gsin(@sscc)
    end
  end

  describe "round-trip validate_gsin(generate_gsin(body)) == {:ok, \"GSIN\"}" do
    for body <- [
          "1061414123456789",
          "0000000000000000",
          "1234567890123456",
          "9999999999999999",
          "3456789012345678"
        ] do
      test "body #{body} round-trips through generate then validate" do
        assert {:ok, gsin} = Keys.generate_gsin(unquote(body))
        assert Keys.validate_gsin(gsin) == {:ok, "GSIN"}
      end
    end
  end

  describe "public ExGtin wiring" do
    test "ExGtin.validate_sscc/1 delegates to ExGtin.Keys.validate_sscc/1" do
      assert ExGtin.validate_sscc(@sscc) == Keys.validate_sscc(@sscc)
    end

    test "ExGtin.generate_sscc/1 delegates to ExGtin.Keys.generate_sscc/1" do
      assert ExGtin.generate_sscc(@sscc_body) == Keys.generate_sscc(@sscc_body)
    end

    test "validate_sscc!/1 returns the string type on success" do
      assert ExGtin.validate_sscc!(@sscc) == "SSCC"
    end

    test "validate_sscc!/1 raises ArgumentError on error" do
      assert_raise ArgumentError, fn -> ExGtin.validate_sscc!("12345") end
    end

    test "generate_sscc!/1 returns the SSCC string on success" do
      assert ExGtin.generate_sscc!(@sscc_body) == @sscc
    end

    test "generate_sscc!/1 raises ArgumentError on error" do
      assert_raise ArgumentError, fn -> ExGtin.generate_sscc!("1234") end
    end

    test "ExGtin.validate_gsin/1 delegates to ExGtin.Keys.validate_gsin/1" do
      assert ExGtin.validate_gsin(@gsin) == Keys.validate_gsin(@gsin)
    end

    test "ExGtin.generate_gsin/1 delegates to ExGtin.Keys.generate_gsin/1" do
      assert ExGtin.generate_gsin(@gsin_body) == Keys.generate_gsin(@gsin_body)
    end

    test "validate_gsin!/1 returns the string type on success" do
      assert ExGtin.validate_gsin!(@gsin) == "GSIN"
    end

    test "validate_gsin!/1 raises ArgumentError on error" do
      assert_raise ArgumentError, fn -> ExGtin.validate_gsin!("12345") end
    end

    test "generate_gsin!/1 returns the GSIN string on success" do
      assert ExGtin.generate_gsin!(@gsin_body) == @gsin
    end

    test "generate_gsin!/1 raises ArgumentError on error" do
      assert_raise ArgumentError, fn -> ExGtin.generate_gsin!("1234") end
    end
  end

  # ---------------------------------------------------------------------------
  # Generic GS1 key path: validate_key/2, generate_key/2.
  #
  # Fixed-length keys and their engine-computed valid vectors (bodies one digit
  # shorter than the key; the check digit is appended by generate_key/2, never
  # hand-invented):
  #
  #   :gln  (13) body "401234500000"      -> "4012345000009"
  #   :gcn  (13) body "401234500000"      -> "4012345000009"
  #   :gdti (13) body "401234500000"      -> "4012345000009"  (base form)
  #   :sscc (18) body "10614141234567890" -> "106141412345678908"
  #   :gsin (17) body "1061414123456789"  -> "10614141234567894"
  #   :gsrn (18) body "40123450000000001" -> "401234500000000012"
  #
  # Note the deliberate collisions used by the explicit-type tests below:
  # gln/gcn/gdti are all 13 digits (and "4012345000009" is a valid mod-10 code),
  # and sscc/gsrn are both 18 digits — only the caller's explicit key names the
  # label.
  # ---------------------------------------------------------------------------

  # {key, valid full code, body used to generate it}. All are pure fixed-length
  # keys (length + mod-10) EXCEPT that :gdti's base 13-digit form is a valid
  # fixed-length code even though :gdti also has a variable-component path.
  @fixed_key_vectors [
    {:gln, "4012345000009", "401234500000"},
    {:gcn, "4012345000009", "401234500000"},
    {:gdti, "4012345000009", "401234500000"},
    {:sscc, "106141412345678908", "10614141234567890"},
    {:gsin, "10614141234567894", "1061414123456789"},
    {:gsrn, "401234500000000012", "40123450000000001"}
  ]

  # The strictly fixed-length keys, where an extra digit or a non-digit is
  # unconditionally an error. :gdti is excluded here because appending a digit
  # to a valid 13-digit GDTI core produces a valid serialized GDTI rather than
  # an error; :gdti's own length/format rules are exercised in its dedicated
  # describe block below.
  @strict_fixed_key_vectors Enum.reject(@fixed_key_vectors, fn {key, _c, _b} -> key == :gdti end)

  describe "validate_key/2 fixed-length: length + checksum" do
    for {key, code, _body} <- @fixed_key_vectors do
      test "a correct-length #{key} with a valid check digit yields {:ok, #{key}}" do
        assert Keys.validate_key(unquote(code), unquote(key)) == {:ok, unquote(key)}
      end

      test "a correct-length #{key} with a wrong check digit yields Invalid Code" do
        {body, [correct]} = Enum.split(String.codepoints(unquote(code)), -1)
        wrong = Integer.to_string(rem(String.to_integer(correct) + 1, 10))
        tampered = Enum.join(body) <> wrong

        assert Keys.validate_key(tampered, unquote(key)) == {:error, "Invalid Code"}
      end

      test "a too-short input for #{key} is rejected" do
        assert {:error, _} = Keys.validate_key("12345", unquote(key))
      end
    end

    for {key, code, _body} <- @strict_fixed_key_vectors do
      test "a too-long input for #{key} is rejected" do
        assert {:error, _} = Keys.validate_key(unquote(code) <> "0", unquote(key))
      end

      test "non-digit content for #{key} is rejected" do
        {body, [_]} = Enum.split(String.codepoints(unquote(code)), -1)
        assert {:error, _} = Keys.validate_key(Enum.join(body) <> "a", unquote(key))
      end
    end
  end

  describe "generate_key/2 fixed-length: appends the check digit" do
    for {key, code, body} <- @fixed_key_vectors do
      test "a correct-length #{key} body yields the full code with a check digit" do
        assert {:ok, generated} = Keys.generate_key(unquote(body), unquote(key))
        assert generated == unquote(code)
        assert String.starts_with?(generated, unquote(body))
      end

      test "a wrong-length #{key} body is rejected" do
        assert {:error, _} = Keys.generate_key("1234", unquote(key))
        # A full-length code is one digit too long to be a body.
        assert {:error, _} = Keys.generate_key(unquote(code), unquote(key))
      end
    end
  end

  describe "generate_key/2 then validate_key/2 round-trips" do
    for {key, _code, body} <- @fixed_key_vectors do
      test "#{key} body round-trips through generate then validate" do
        assert {:ok, code} = Keys.generate_key(unquote(body), unquote(key))
        assert Keys.validate_key(code, unquote(key)) == {:ok, unquote(key)}
      end
    end
  end

  describe "explicit key type prevents same-length collisions" do
    test "the same valid 18-digit code validates as :sscc or :gsrn per the caller" do
      # Both keys are length 18; the caller's explicit key names the label.
      code = "401234500000000012"
      assert Keys.validate_key(code, :sscc) == {:ok, :sscc}
      assert Keys.validate_key(code, :gsrn) == {:ok, :gsrn}
    end

    test "another valid 18-digit code also labels by the caller's key, not length" do
      code = "106141412345678908"
      assert Keys.validate_key(code, :sscc) == {:ok, :sscc}
      assert Keys.validate_key(code, :gsrn) == {:ok, :gsrn}
    end

    test "the same valid 13-digit code validates as :gln, :gcn, or :gdti per the caller" do
      # gln, gcn, and gdti (base form) are all length 13.
      code = "4012345000009"
      assert Keys.validate_key(code, :gln) == {:ok, :gln}
      assert Keys.validate_key(code, :gcn) == {:ok, :gcn}
      assert Keys.validate_key(code, :gdti) == {:ok, :gdti}
    end
  end

  describe "unknown key yields Unsupported key" do
    test "an unrecognized key atom is rejected on validate" do
      assert Keys.validate_key("4012345000009", :bogus) == {:error, "Unsupported key"}
    end

    test "an unrecognized key atom is rejected on generate" do
      assert Keys.generate_key("401234500000", :bogus) == {:error, "Unsupported key"}
    end
  end

  describe "variable-component key GRAI: format validation" do
    test "a valid 14-digit numeric core (no serial) validates" do
      assert Keys.validate_key("00614141543212", :grai) == {:ok, :grai}
    end

    test "a valid core with a CSET-82 serial validates" do
      assert Keys.validate_key("00614141543212Ab7/", :grai) == {:ok, :grai}
    end

    test "a core with a wrong check digit yields Invalid Code" do
      assert Keys.validate_key("00614141543213", :grai) == {:error, "Invalid Code"}
    end

    test "a serial with an out-of-charset character (space) is rejected" do
      assert Keys.validate_key("00614141543212Ab 7", :grai) == {:error, "Invalid GRAI"}
    end

    test "a serial longer than 16 characters is rejected" do
      long_serial = String.duplicate("A", 17)
      assert Keys.validate_key("00614141543212" <> long_serial, :grai) == {:error, "Invalid GRAI"}
    end

    test "a numeric core without the leading zero is rejected as malformed" do
      # 14 digits that do not begin with "0" is not a well-formed GRAI core.
      assert Keys.validate_key("10614141543217", :grai) == {:error, "Invalid GRAI"}
    end

    test "generate_key/2 for :grai is unsupported" do
      assert Keys.generate_key("00000000", :grai) == {:error, "Unsupported key"}
    end
  end

  describe "variable-component key GIAI: format validation" do
    test "a numeric-prefixed value validates" do
      assert Keys.validate_key("4000001111", :giai) == {:ok, :giai}
    end

    test "a numeric-prefixed alphanumeric value validates" do
      assert Keys.validate_key("40000011112ABCxyz", :giai) == {:ok, :giai}
    end

    test "a value that does not start with a digit is rejected" do
      assert Keys.validate_key("ABC123", :giai) == {:error, "Invalid GIAI"}
    end

    test "an empty value is rejected" do
      assert Keys.validate_key("", :giai) == {:error, "Invalid GIAI"}
    end

    test "a value longer than 30 characters is rejected" do
      long = "4" <> String.duplicate("A", 30)
      assert Keys.validate_key(long, :giai) == {:error, "Invalid GIAI"}
    end

    test "an out-of-charset character (space) is rejected" do
      assert Keys.validate_key("4000 1111", :giai) == {:error, "Invalid GIAI"}
    end

    test "generate_key/2 for :giai is unsupported" do
      assert Keys.generate_key("00000000", :giai) == {:error, "Unsupported key"}
    end
  end

  describe "variable-component key GDTI: format validation" do
    test "a valid 13-digit core (no serial) validates" do
      assert Keys.validate_key("4012345000009", :gdti) == {:ok, :gdti}
    end

    test "a valid core with a numeric serial validates" do
      assert Keys.validate_key("4012345000009123456", :gdti) == {:ok, :gdti}
    end

    test "a core with a wrong check digit yields Invalid Code" do
      assert Keys.validate_key("4012345000008", :gdti) == {:error, "Invalid Code"}
    end

    test "a non-numeric serial is rejected" do
      assert Keys.validate_key("4012345000009123abc", :gdti) == {:error, "Invalid GDTI"}
    end

    test "a numeric serial longer than 17 digits is rejected" do
      long_serial = String.duplicate("1", 18)
      assert Keys.validate_key("4012345000009" <> long_serial, :gdti) == {:error, "Invalid GDTI"}
    end

    test "a core shorter than 13 digits is rejected as malformed" do
      assert Keys.validate_key("401234500000", :gdti) == {:error, "Invalid GDTI"}
    end

    test "generate_key/2 for :gdti produces only the base 13-digit form" do
      assert Keys.generate_key("401234500000", :gdti) == {:ok, "4012345000009"}
    end
  end

  describe "public ExGtin.validate_key/2 and generate_key/2 wiring" do
    test "ExGtin.validate_key/2 delegates to ExGtin.Keys.validate_key/2" do
      for {key, code, _body} <- @fixed_key_vectors do
        assert ExGtin.validate_key(code, key) == Keys.validate_key(code, key)
        assert ExGtin.validate_key(code, key) == {:ok, key}
      end
    end

    test "ExGtin.generate_key/2 delegates to ExGtin.Keys.generate_key/2" do
      for {key, _code, body} <- @fixed_key_vectors do
        assert ExGtin.generate_key(body, key) == Keys.generate_key(body, key)
      end
    end

    test "ExGtin.validate_key/2 delegates the variable-component keys" do
      assert ExGtin.validate_key("00614141543212", :grai) == {:ok, :grai}
      assert ExGtin.validate_key("4000001111", :giai) == {:ok, :giai}
      assert ExGtin.validate_key("4012345000009123456", :gdti) == {:ok, :gdti}
    end

    test "ExGtin.generate_key/2 rejects the variable-component keys" do
      assert ExGtin.generate_key("00000000", :grai) == {:error, "Unsupported key"}
      assert ExGtin.generate_key("00000000", :giai) == {:error, "Unsupported key"}
    end
  end
end
