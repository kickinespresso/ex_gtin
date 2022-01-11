defmodule ExGtin.ValidationTest do
  @moduledoc """
  Validation Module Test
  """
  use ExUnit.Case
  doctest ExGtin.Validation
  import ExGtin.Validation

  describe "gtin_check_digit function" do
    test "with valid number string" do
      number = "6291041500213"
      assert {:ok, "GTIN-13"} == gtin_check_digit(number)
    end

    test "with valid number array" do
      number = [6, 2, 9, 1, 0, 4, 1, 5, 0, 0, 2, 1, 3]
      assert {:ok, "GTIN-13"} == gtin_check_digit(number)
    end

    test "with valid number as integer" do
      number = 6_291_041_500_213
      assert {:ok, "GTIN-13"} == gtin_check_digit(number)
    end

    test "with valid number as string" do
      number = "6291041500213"
      assert {:ok, "GTIN-13"} == gtin_check_digit(number)
    end

    test "with invalid number" do
      number = "6291041500214"
      assert {:error, "Invalid Code"} == gtin_check_digit(number)
      assert {:error, "Invalid Code"} == gtin_check_digit("6291041533213")
    end

    test "with invalid length" do
      number = "62910415002143232232"
      assert {:error, "Invalid GTIN Code Length"} == gtin_check_digit(number)
      assert {:error, _} = gtin_check_digit("62910415002143232232")
    end
  end

  test "mult_by_index_code function" do
    assert mult_by_index_code(1) == 1
    assert mult_by_index_code(2) == 3
    assert mult_by_index_code(3) == 1
    assert mult_by_index_code(4) == 3
  end

  test "multiply_and_sum_array function" do
    number = [6, 2, 9, 1, 0, 4, 1, 5, 0, 0, 2, 1]
    assert 57 == multiply_and_sum_array(number)
  end

  test "generate_check_digit function" do
    number = [6, 2, 9, 1, 0, 4, 1, 5, 0, 0, 2, 1]
    assert 3 == generate_check_digit(number)
  end

  test "subtract_from_nearest_multiple_of_ten function" do
    assert 3 == subtract_from_nearest_multiple_of_ten(57)
  end

  test "check_code_length function with valid codes" do
    codes = [
      [1, 2, 3, 4, 5, 6, 7, 8],
      [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
      [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13],
      [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]
    ]

    Enum.map(codes, fn(x) -> assert {:ok, "GTIN-#{length(x)}"} == check_code_length(x) end)
  end

  test "check_code_length function with invalid code" do
    code = [1, 2, 3, 4, 5, 6, 7]
    assert {:error, _} = check_code_length(code)
  end

  test "generate_check_code_length function with valid codes" do
    codes = [
      [1, 2, 3, 4, 5, 6, 7],
      [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
      [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
      [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]
    ]
    Enum.map(codes, fn(x) ->
      assert {:ok, "GTIN-#{length(x) + 1}"} == generate_check_code_length(x)
    end)
  end

  test "generate_check_code_length function with invalid code" do
    code = [1, 2, 3, 4, 5, 6]
    assert {:error, _} = generate_check_code_length(code)
  end

  describe "generate_gtin_code/1 function" do
    test "with valid number string" do
      number = "629104150021"
      assert {:ok, "6291041500213"} == generate_gtin_code(number)
    end

    test "with valid number array" do
      number = [6, 2, 9, 1, 0, 4, 1, 5, 0, 0, 2, 1]
      assert {:ok, "6291041500213"} == generate_gtin_code(number)
    end

    test "with valid number " do
      number = 629_104_150_021
      assert {:ok, "6291041500213"} == generate_gtin_code(number)
    end
  end

  test "find_gs1_prefix_country function with valid number " do
    number = "53523235"
    assert {:ok, "GS1 Malta"} == find_gs1_prefix_country(number)
  end

  test "find_gs1_prefix_country function with invalid prefix code " do
    number = "00023235"
    assert {:error, "No GS1 prefix found"} == find_gs1_prefix_country(number)
  end

  test "find_gs1_prefix_country function with invalid number " do
    number = "00035"
    assert {:error, "Invalid GTIN Code Length"} == find_gs1_prefix_country(number)
  end

  test "lookup_gs1_prefix test country codes" do
    assert lookup_gs1_prefix(001) == {:ok, "GS1 US"}
    assert lookup_gs1_prefix(030) == {:ok, "GS1 US"}
    assert lookup_gs1_prefix(001) == {:ok, "GS1 US"}
    assert lookup_gs1_prefix(050) == {:ok, "GS1 US"}
    assert lookup_gs1_prefix(060) == {:ok, "GS1 US"}
    assert lookup_gs1_prefix(100) == {:ok, "GS1 US"}
    assert lookup_gs1_prefix(535) == {:ok, "GS1 Malta"}
    assert lookup_gs1_prefix(020) == {:ok, "Used to issue restricted circulation numbers within a geographic region (MO defined)"}
    assert lookup_gs1_prefix(040) == {:ok, "Used to issue GS1 restricted circulation numbers within a company"}
    assert lookup_gs1_prefix(200) == {:ok, "Used to issue GS1 restricted circulation number within a geographic region (MO defined)"}
    assert lookup_gs1_prefix(300) == {:ok, "GS1 France"}
    assert lookup_gs1_prefix(380) == {:ok, "GS1 Bulgaria"}
    assert lookup_gs1_prefix(383) == {:ok, "GS1 Slovenija"}
    assert lookup_gs1_prefix(385) == {:ok, "GS1 Croatia"}
    assert lookup_gs1_prefix(387) == {:ok, "GS1 BIH (Bosnia-Herzegovina)"}
    assert lookup_gs1_prefix(389) == {:ok, "GS1 Montenegro"}
    assert lookup_gs1_prefix(400) == {:ok, "GS1 Germany"}
    assert lookup_gs1_prefix(450) == {:ok, "GS1 Japan"}
    assert lookup_gs1_prefix(490) == {:ok, "GS1 Japan"}
    assert lookup_gs1_prefix(460) == {:ok, "GS1 Russia"}
    assert lookup_gs1_prefix(470) == {:ok, "GS1 Kyrgyzstan"}
    assert lookup_gs1_prefix(471) == {:ok, "GS1 Taiwan"}
    assert lookup_gs1_prefix(474) == {:ok, "GS1 Estonia"}
    assert lookup_gs1_prefix(475) == {:ok, "GS1 Latvia"}
    assert lookup_gs1_prefix(476) == {:ok, "GS1 Azerbaijan"}
    assert lookup_gs1_prefix(477) == {:ok, "GS1 Lithuania"}
    assert lookup_gs1_prefix(478) == {:ok, "GS1 Uzbekistan"}
    assert lookup_gs1_prefix(479) == {:ok, "GS1 Sri Lanka"}
    assert lookup_gs1_prefix(480) == {:ok, "GS1 Philippines"}
    assert lookup_gs1_prefix(481) == {:ok, "GS1 Belarus"}
    assert lookup_gs1_prefix(482) == {:ok, "GS1 Ukraine"}
    assert lookup_gs1_prefix(483) == {:ok, "GS1 Turkmenistan"}
    assert lookup_gs1_prefix(484) == {:ok, "GS1 Moldova"}
    assert lookup_gs1_prefix(485) == {:ok, "GS1 Armenia"}
    assert lookup_gs1_prefix(486) == {:ok, "GS1 Georgia"}
    assert lookup_gs1_prefix(487) == {:ok, "GS1 Kazakstan"}
    assert lookup_gs1_prefix(488) == {:ok, "GS1 Tajikistan"}
    assert lookup_gs1_prefix(489) == {:ok, "GS1 Hong Kong"}
    assert lookup_gs1_prefix(500) == {:ok, "GS1 UK"}
    assert lookup_gs1_prefix(520) == {:ok, "GS1 Association Greece"}
    assert lookup_gs1_prefix(528) == {:ok, "GS1 Lebanon"}
    assert lookup_gs1_prefix(529) == {:ok, "GS1 Cyprus"}
    assert lookup_gs1_prefix(530) == {:ok, "GS1 Albania"}
    assert lookup_gs1_prefix(531) == {:ok, "GS1 Macedonia"}
    assert lookup_gs1_prefix(535) == {:ok, "GS1 Malta"}
    assert lookup_gs1_prefix(539) == {:ok, "GS1 Ireland"}
    assert lookup_gs1_prefix(540) == {:ok, "GS1 Belgium & Luxembourg"}
    assert lookup_gs1_prefix(560) == {:ok, "GS1 Portugal"}
    assert lookup_gs1_prefix(569) == {:ok, "GS1 Iceland"}
    assert lookup_gs1_prefix(570) == {:ok, "GS1 Denmark"}
    assert lookup_gs1_prefix(590) == {:ok, "GS1 Poland"}
    assert lookup_gs1_prefix(594) == {:ok, "GS1 Romania"}
    assert lookup_gs1_prefix(599) == {:ok, "GS1 Hungary"}
    assert lookup_gs1_prefix(600) == {:ok, "GS1 South Africa"}
    assert lookup_gs1_prefix(603) == {:ok, "GS1 Ghana"}
    assert lookup_gs1_prefix(604) == {:ok, "GS1 Senegal"}
    assert lookup_gs1_prefix(608) == {:ok, "GS1 Bahrain"}
    assert lookup_gs1_prefix(609) == {:ok, "GS1 Mauritius"}
    assert lookup_gs1_prefix(611) == {:ok, "GS1 Morocco"}
    assert lookup_gs1_prefix(613) == {:ok, "GS1 Algeria"}
    assert lookup_gs1_prefix(615) == {:ok, "GS1 Nigeria"}
    assert lookup_gs1_prefix(616) == {:ok, "GS1 Kenya"}
    assert lookup_gs1_prefix(618) == {:ok, "GS1 Ivory Coast"}
    assert lookup_gs1_prefix(619) == {:ok, "GS1 Tunisia"}
    assert lookup_gs1_prefix(620) == {:ok, "GS1 Tanzania"}
    assert lookup_gs1_prefix(621) == {:ok, "GS1 Syria"}
    assert lookup_gs1_prefix(622) == {:ok, "GS1 Egypt"}
    assert lookup_gs1_prefix(623) == {:ok, "GS1 Brunei"}
    assert lookup_gs1_prefix(624) == {:ok, "GS1 Libya"}
    assert lookup_gs1_prefix(625) == {:ok, "GS1 Jordan"}
    assert lookup_gs1_prefix(626) == {:ok, "GS1 Iran"}
    assert lookup_gs1_prefix(627) == {:ok, "GS1 Kuwait"}
    assert lookup_gs1_prefix(628) == {:ok, "GS1 Saudi Arabia"}
    assert lookup_gs1_prefix(629) == {:ok, "GS1 Emirates"}
    assert lookup_gs1_prefix(640) == {:ok, "GS1 Finland"}
    assert lookup_gs1_prefix(690) == {:ok, "GS1 China"}
    assert lookup_gs1_prefix(700) == {:ok, "GS1 Norway"}
    assert lookup_gs1_prefix(729) == {:ok, "GS1 Israel"}
    assert lookup_gs1_prefix(730) == {:ok, "GS1 Sweden"}
    assert lookup_gs1_prefix(740) == {:ok, "GS1 Guatemala"}
    assert lookup_gs1_prefix(741) == {:ok, "GS1 El Salvador"}
    assert lookup_gs1_prefix(742) == {:ok, "GS1 Honduras"}
    assert lookup_gs1_prefix(743) == {:ok, "GS1 Nicaragua"}
    assert lookup_gs1_prefix(744) == {:ok, "GS1 Costa Rica"}
    assert lookup_gs1_prefix(745) == {:ok, "GS1 Panama"}
    assert lookup_gs1_prefix(746) == {:ok, "GS1 Republica Dominicana"}
    assert lookup_gs1_prefix(750) == {:ok, "GS1 Mexico"}
    assert lookup_gs1_prefix(754) == {:ok, "GS1 Canada"}
    assert lookup_gs1_prefix(759) == {:ok, "GS1 Venezuela"}
    assert lookup_gs1_prefix(760) == {:ok, "GS1 Schweiz, Suisse, Svizzera"}
    assert lookup_gs1_prefix(770) == {:ok, "GS1 Colombia"}
    assert lookup_gs1_prefix(773) == {:ok, "GS1 Uruguay"}
    assert lookup_gs1_prefix(775) == {:ok, "GS1 Peru"}
    assert lookup_gs1_prefix(777) == {:ok, "GS1 Bolivia"}
    assert lookup_gs1_prefix(778) == {:ok, "GS1 Argentina"}
    assert lookup_gs1_prefix(780) == {:ok, "GS1 Chile"}
    assert lookup_gs1_prefix(784) == {:ok, "GS1 Paraguay"}
    assert lookup_gs1_prefix(786) == {:ok, "GS1 Ecuador"}
    assert lookup_gs1_prefix(789) == {:ok, "GS1 Brasil"}
    assert lookup_gs1_prefix(800) == {:ok, "GS1 Italy"}
    assert lookup_gs1_prefix(840) == {:ok, "GS1 Spain"}
    assert lookup_gs1_prefix(850) == {:ok, "GS1 Cuba"}
    assert lookup_gs1_prefix(858) == {:ok, "GS1 Slovakia"}
    assert lookup_gs1_prefix(859) == {:ok, "GS1 Czech"}
    assert lookup_gs1_prefix(860) == {:ok, "GS1 Serbia"}
    assert lookup_gs1_prefix(865) == {:ok, "GS1 Mongolia"}
    assert lookup_gs1_prefix(867) == {:ok, "GS1 North Korea"}
    assert lookup_gs1_prefix(868) == {:ok, "GS1 Turkey"}
    assert lookup_gs1_prefix(870) == {:ok, "GS1 Netherlands"}
    assert lookup_gs1_prefix(880) == {:ok, "GS1 South Korea"}
    assert lookup_gs1_prefix(884) == {:ok, "GS1 Cambodia"}
    assert lookup_gs1_prefix(885) == {:ok, "GS1 Thailand"}
    assert lookup_gs1_prefix(888) == {:ok, "GS1 Singapore"}
    assert lookup_gs1_prefix(890) == {:ok, "GS1 India"}
    assert lookup_gs1_prefix(893) == {:ok, "GS1 Vietnam"}
    assert lookup_gs1_prefix(896) == {:ok, "GS1 Pakistan"}
    assert lookup_gs1_prefix(899) == {:ok, "GS1 Indonesia"}
    assert lookup_gs1_prefix(900) == {:ok, "GS1 Austria"}
    assert lookup_gs1_prefix(930) == {:ok, "GS1 Australia"}
    assert lookup_gs1_prefix(940) == {:ok, "GS1 New Zealand"}
    assert lookup_gs1_prefix(950) == {:ok, "GS1 Global Office"}
    assert lookup_gs1_prefix(951) == {:ok, "Used to issue General Manager Numbers for the EPC General Identifier (GID) scheme as defined by the EPC Tag Data Standard*"}
    assert lookup_gs1_prefix(955) == {:ok, "GS1 Malaysia"}
    assert lookup_gs1_prefix(958) == {:ok, "GS1 Macau"}
    assert lookup_gs1_prefix(960) == {:ok, "Global Office (GTIN-8s)*"}
    assert lookup_gs1_prefix(977) == {:ok, "Serial publications (ISSN)"}
    assert lookup_gs1_prefix(978) == {:ok, "Bookland (ISBN)"}
    assert lookup_gs1_prefix(980) == {:ok, "Refund receipts"}
    assert lookup_gs1_prefix(981) == {:ok, "GS1 coupon identification for common currency areas"}
    assert lookup_gs1_prefix(990) == {:ok, "GS1 coupon identification"}
  end

end
