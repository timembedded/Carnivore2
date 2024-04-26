
----------------------------------------------------------------
-- v2.50.0003
----------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;


entity top is
  port(
    -- PLL
    clk50       : IN std_logic;

    -- ADC
    adc_md      : OUT std_logic_vector(1 downto 0);
    adc_scki    : OUT std_logic;
    adc_bck     : OUT std_logic;
    adc_lrck    : OUT std_logic;
    adc_dout    : IN std_logic;

    -- DAC
    dac_xsmt    : OUT std_logic;
    dac_lrck    : OUT std_logic;
    dac_din     : OUT std_logic;
    dac_bck     : OUT std_logic;
    dac_sck     : OUT std_logic;
    dac_flt     : OUT std_logic;
    dac_demp    : OUT std_logic;

    -- SLOT
    pSltClk     : IN std_logic;
    pSltRst1_n   : IN std_logic;
    pSltSltsls_n : IN std_logic;
    pSltIorq_n  : IN std_logic;
    pSltRd_n    : IN std_logic;
    pSltWr_n    : IN std_logic;
    pSltAdr     : IN std_logic_vector(15 downto 0);
    pSltDat     : INOUT std_logic_vector(7 downto 0);
    pSltBdir_n  : OUT std_logic;

    pSltCs1     : IN std_logic;
    pSltCs2     : IN std_logic;
    pSltCs12    : IN std_logic;
    pSltRfsh_n  : IN std_logic;
    pSltWait_n  : INOUT std_logic;
    pSltInt_n   : IN std_logic;
    pSltM1_n    : IN std_logic;
    pSltMerq_n  : IN std_logic;

    pSltRsv5    : IN std_logic;
    pSltRsv16   : IN std_logic;

    -- FLASH ROM interface
    pFlAdr      : OUT std_logic_vector(22 downto 0);
    pFlDat      : INOUT std_logic_vector(7 downto 0);
    pFlCS_n     : OUT std_logic;
    pFlOE_n     : OUT std_logic;
    pFlW_n      : OUT std_logic;
    pFlRP_n     : OUT std_logic;
    pFlRB_b     : IN std_logic;
    pFlVpp      : OUT std_logic;

    -- RAM chip ( Flash bus + rsc )
    pRAMCS_n    : OUT std_logic;

    -- CF card interface
    pIDEAdr     : OUT std_logic_vector(2 downto 0);
    pIDEDat     : INOUT std_logic_vector(15 downto 0);
    pIDECS1_n   : OUT std_logic;
    pIDECS3_n   : OUT std_logic;
    pIDERD_n    : OUT std_logic;
    pIDEWR_n    : OUT std_logic;
    pPIN180     : OUT std_logic;
    pIDE_Rst_n  : OUT std_logic;

    --  EEPROM
    EECS    : OUT std_logic;
    EECK    : OUT std_logic;
    EEDI    : OUT std_logic;
    EEDO    : in std_logic;

    -- DEBUG
    J2_2        : OUT std_logic;
    J2_3        : OUT std_logic

);
end top;

architecture RTL of top is

  -- Clock and reset
  signal sysclk     : std_logic;
  signal locked     : std_logic;
  signal reset      : std_logic;
  signal pSltClk_n  : std_logic;
  signal pSltRst_n  : std_logic := '0' ;
  signal RstEn 	    : std_logic := '0';

  signal count : std_logic_vector(1 downto 0) := "00";
  signal audio_ack_i : std_logic;
  signal left_tone_enable_i : std_logic;
  signal left_tone_select_i : std_logic;
  signal right_tone_enable_i : std_logic;
  signal right_tone_select_i : std_logic;
  signal audio_output_left_i : std_logic_vector(15 downto 0);
  signal audio_output_right_i : std_logic_vector(15 downto 0);
  signal config_reg : std_logic_vector(7 downto 0);
  signal ram_enable : std_logic;

  -- Slot interface
  signal DOutEn       : std_logic;
  signal DOut         : std_logic_vector(7 downto 0);

  -- MAPPER RAM
  signal MAP_FF      : std_logic_vector(6 downto 0);
  signal MAP_FE      : std_logic_vector(6 downto 0);
  signal MAP_FD      : std_logic_vector(6 downto 0);
  signal MAP_FC      : std_logic_vector(6 downto 0);
  signal AddrMAP     : std_logic_vector(6 downto 0); 

begin

  -- Flash
  pFlCS_n <= '1';

  -- ADC
  adc_md <= "00";
  adc_scki <= '0';
  adc_bck  <= '0';
  adc_lrck <= '0';

  -- DAC
  dac_xsmt <= '1';
  dac_flt  <= '0';
  dac_demp <= '0';

  -- Debug
  J2_2 <= count(0);
  J2_3 <= count(1);

  left_tone_enable_i <= config_reg(7);
  right_tone_enable_i <= config_reg(6);
  left_tone_select_i <= config_reg(5);
  right_tone_select_i <= config_reg(4);

  ram_enable <= config_reg(0);

  process(sysclk)
  begin
    if rising_edge(sysclk) then
      if reset = '1' then
        count <= (others => '0');
      else
        count <= count + 1;
      end if;
    end if;
  end process;

  --------------------------------------------------------------------
  -- Clock / reset
  --------------------------------------------------------------------

  i_pll1 : entity work.mpll1(syn)
  port map
  (
    areset  => '0',
    inclk0  => clk50,
    c0      => sysclk,
    locked  => locked
  );

  i_clock_reset : entity work.generate_clock_enables(rtl)
  generic map(
    FREQ_MHZ => 50
  )
  port map
  (
    clk => sysclk,
    pll_locked => locked,
    reset => reset,
    clken1ms => open
  );

  --------------------------------------------------------------------
  -- Config/test register
  --------------------------------------------------------------------

  process(reset, sysclk)
  begin
    if (reset = '1') then
      config_reg <= x"00";
    elsif rising_edge(sysclk) then
      if pSltWr_n = '0' then
        if(pSltAdr(7 downto 0) = x"52" and pSltIorq_n = '0') then
          config_reg <= pSltDat;
        end if;
      end if;
    end if;
  end process;

  --------------------------------------------------------------------
  -- Waveform generators
  --------------------------------------------------------------------

  i_waveform_generator_left : entity work.waveform_generator(rtl)
  port map
  (
    clk => sysclk,
    reset => reset,
    audio_strobe => audio_ack_i,
    tone_enable => left_tone_enable_i,
    tone_select => left_tone_select_i,
    audio_input => (others => '0'),
    audio_output => audio_output_left_i
  );

  i_waveform_generator_right : entity work.waveform_generator(rtl)
  port map
  (
    clk => sysclk,
    reset => reset,
    audio_strobe => audio_ack_i,
    tone_enable => right_tone_enable_i,
    tone_select => right_tone_select_i,
    audio_input => (others => '0'),
    audio_output => audio_output_right_i
  );

  --------------------------------------------------------------------
  -- Audio output
  --------------------------------------------------------------------

  i_i2s_output : entity work.i2s_output(rtl)
  port map
  (
    clock => sysclk,
    reset => reset,
    audio_left => audio_output_left_i,
    audio_right => audio_output_right_i,
    audio_ack => audio_ack_i,
    i2s_mclk => dac_sck,
    i2s_lrclk => dac_lrck,
    i2s_sclk => dac_bck,
    i2s_data => dac_din
  );

  --------------------------------------------------------------------
  -- Memory mapper
  --------------------------------------------------------------------

  process(reset, sysclk)
  begin
    if (reset = '1') then
      MAP_FC <= "0000011" ;
      MAP_FD <= "0000010" ;
      MAP_FE <= "0000001" ;
      MAP_FF <= "0000000" ;
    elsif (sysclk'event and sysclk = '1') then
      if pSltWr_n = '0' then
        if(pSltAdr(7 downto 0) = x"FC" and pSltIorq_n = '0') then
          MAP_FC <= pSltDat(6 downto 0);
        end if;
        if(pSltAdr(7 downto 0) = x"FD" and pSltIorq_n = '0') then
          MAP_FD <= pSltDat(6 downto 0);
        end if;
        if(pSltAdr(7 downto 0) = x"FE" and pSltIorq_n = '0') then
          MAP_FE <= pSltDat(6 downto 0);
        end if;
        if(pSltAdr(7 downto 0) = x"FF" and pSltIorq_n = '0') then
          MAP_FF <= pSltDat(6 downto 0);
        end if;
      end if;
    end if;
  end process;

  --------------------------------------------------------------------
  -- Adress Flash/ROM mapping
  --------------------------------------------------------------------

  pFlAdr(22 downto 0) <= "01" & AddrMAP(6 downto 0) & pSltAdr(13 downto 0); -- Mapper RAM 

  AddrMAP <=  MAP_FC when  pSltAdr(15 downto 14) = "00" else  -- Mapper Page
        MAP_FD when  pSltAdr(15 downto 14) = "01" else  
        MAP_FE when  pSltAdr(15 downto 14) = "10" else  
        MAP_FF;

  ----------------------------------------------------------------
  -- Flash ROM/RAM interface 
  ---------------------------------------------------------------- 

  -- Flash/RAM DataWrite
  pFlDat <= pSltDat when pSltSltsls_n = '0' and pSltMerq_n = '0' and pSltWr_n = '0'
       else (others => 'Z');

  ----------------------------------------------------------------
  -- Data output to slot
  ---------------------------------------------------------------- 

  pSltWait_n <= 'Z';

  DOutEn  <= '1' when pSltRd_n = '0' and pSltMerq_n = '0' and pSltSltsls_n = '0' and ram_enable = '1'  -- memory mapper
        else '1' when pSltRd_n = '0' and pSltIorq_n = '0' and pSltAdr(7 downto 0) = x"52"              -- config register
        else '0';
          
  DOut    <=  config_reg when pSltAdr(7 downto 0) = x"52" and pSltIorq_n = '0' else
              pFlDat;

  pSltDat   <= DOut when DOutEn = '1' else (others => 'Z');

  pSltBdir_n <= '0' when pSltRd_n = '0' and pSltIorq_n = '0' and pSltAdr(7 downto 0) = x"52"    -- config register
           else '1';

  pRAMCS_n <= '0' when pSltMerq_n = '0' and pSltSltsls_n = '0' and ram_enable = '1'
         else '1';

  pFlW_n <= pSltWr_n;
  pFlOE_n <= pSltRd_n;

end RTL;

  