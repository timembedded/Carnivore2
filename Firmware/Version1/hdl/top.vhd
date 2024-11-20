------------------------------------------------------------------------
-- Copyright (C) 2024 Tim Brugman
--
--  This firmware is free code: you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published
--  by the Free Software Foundation, version 3
--
--  This firmware is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE
--  See the GNU General Public License for more details
--
--  You should have received a copy of the GNU General Public License
--  along with this program. If not, see https://www.gnu.org/licenses/
--
------------------------------------------------------------------------
-- Carnivore2 custom firmware toplevel
------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

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
    pSltBdir_n  : INOUT std_logic;

    pSltCs1     : IN std_logic;
    pSltCs2     : IN std_logic;
    pSltCs12    : IN std_logic;
    pSltRfsh_n  : IN std_logic;
    pSltWait_n  : INOUT std_logic;
    pSltInt_n   : INOUT std_logic;
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
    EECS        : OUT std_logic;
    EECK        : OUT std_logic;
    EEDI        : OUT std_logic;
    EEDO        : in std_logic;

    -- DEBUG
    J2_2        : OUT std_logic;
    J2_3        : OUT std_logic

);
end top;

architecture rtl of top is

  -- Constants
  constant clock_divider_3m58 : integer := 28;  -- 100 MHz / 28 = 3.571 MHz
  constant LVF                : std_logic_vector(2 downto 0) := "111"; -- Level FM-PAC


  -- Clock and reset
  signal sysclk     : std_logic;
  signal locked     : std_logic;
  signal reset      : std_logic;
  signal clken1ms_i : std_logic;

  -- Clock divider for 3.58 MHz clock
  signal clkena_3m58_i  : std_logic;

  -- Avalon memory master
  signal mem_read_i           : std_logic;
  signal mem_write_i          : std_logic;
  signal mem_address_i        : std_logic_vector(16 downto 0);
  signal mem_writedata_i      : std_logic_vector(7 downto 0);
  signal mem_readdata_i       : std_logic_vector(8 downto 0);
  signal mem_readdatavalid_i  : std_logic;
  signal mem_waitrequest_i    : std_logic;

  -- Avalon io master
  signal iom_read_i           : std_logic;
  signal iom_write_i          : std_logic;
  signal iom_address_i        : std_logic_vector(7 downto 0);
  signal iom_writedata_i      : std_logic_vector(7 downto 0);
  signal iom_readdata_i       : std_logic_vector(8 downto 0);
  signal iom_readdatavalid_i  : std_logic;
  signal iom_waitrequest_i    : std_logic;

    -- io sniffer for writes
  signal ism_address_i              : std_logic_vector(8 downto 0);
  signal ism_write_i                : std_logic;
  signal ism_writedata_i            : std_logic_vector(7 downto 0);
  signal ism_waitrequest_i          : std_logic;

  -- Keyboard sniffer
  signal key_num_i                  : std_logic_vector(9 downto 0);
  signal key_shift_i                : std_logic;
  signal key_ctrl_i                 : std_logic;
  signal key_graph_i                : std_logic;
  signal key_code_i                 : std_logic;

  -- Synchronous resets
  signal slot_reset_i               : std_logic;
  signal soft_reset_i               : std_logic;

  -- Misc card
  signal our_slot_i                 : std_logic_vector(1 downto 0);
  signal enable_shadow_ram_i        : std_logic;

  -- SCC mode registers
  signal EseScc_MA19_i              : std_logic; -- EseScc_xxx was SccModeA
  signal EseScc_MA20_i              : std_logic;
  signal SccPlus_Enable_i           : std_logic; -- SccPlus_xxx was SccModeB
  signal SccPlus_AllRam_i           : std_logic;
  signal SccPlus_B0Ram_i            : std_logic;
  signal SccPlus_B1Ram_i            : std_logic;
  signal SccPlus_B2Ram_i            : std_logic;

  -- Functions
  signal beep_i                     : std_logic;
  signal enable_expand_i            : std_logic;
  signal enable_ide_a_i, enable_ide_b_i       : std_logic;
  signal enable_mapper_a_i, enable_mapper_b_i : std_logic;
  signal enable_fmpac_a_i, enable_fmpac_b_i   : std_logic;
  signal enable_scc_a_i, enable_scc_b_i       : std_logic;

  -- Flash avalon slave port
  signal mem_flash_read_i           : std_logic;
  signal mem_flash_address_i        : std_logic_vector(22 downto 0);
  signal mem_flash_readdata_i       : std_logic_vector(7 downto 0);
  signal mem_flash_readdatavalid_i  : std_logic;
  signal mem_flash_waitrequest_i    : std_logic;

  -- RAM avalon slave port
  signal mem_ram_read_i             : std_logic;
  signal mem_ram_write_i            : std_logic;
  signal mem_ram_address_i          : std_logic_vector(20 downto 0);
  signal mem_ram_writedata_i        : std_logic_vector(7 downto 0);
  signal mem_ram_readdata_i         : std_logic_vector(7 downto 0);
  signal mem_ram_readdatavalid_i    : std_logic;
  signal mem_ram_waitrequest_i      : std_logic;

  -- Flash+RAM avalon slave port
  signal mem_flashram_read_i          : std_logic;
  signal mem_flashram_write_i         : std_logic;
  signal mem_flashram_address_i       : std_logic_vector(23 downto 0);
  signal mem_flashram_writedata_i     : std_logic_vector(7 downto 0);
  signal mem_flashram_readdata_i      : std_logic_vector(7 downto 0);
  signal mem_flashram_readdatavalid_i : std_logic;
  signal mem_flashram_waitrequest_i   : std_logic;

  -- Avalon bus: Memory mapper
  signal mem_mapper_read_i          : std_logic;
  signal mem_mapper_write_i         : std_logic;
  signal mem_mapper_address_i       : std_logic_vector(15 downto 0);
  signal mem_mapper_writedata_i     : std_logic_vector(7 downto 0);
  signal mem_mapper_readdata_i      : std_logic_vector(7 downto 0);
  signal mem_mapper_readdatavalid_i : std_logic;
  signal mem_mapper_waitrequest_i   : std_logic;
  signal iom_mapper_read_i          : std_logic;
  signal iom_mapper_write_i         : std_logic;
  signal iom_mapper_address_i       : std_logic_vector(1 downto 0);
  signal iom_mapper_writedata_i     : std_logic_vector(7 downto 0);
  signal iom_mapper_readdata_i      : std_logic_vector(7 downto 0);
  signal iom_mapper_readdatavalid_i : std_logic;
  signal iom_mapper_waitrequest_i   : std_logic;
  -- RAM
  signal ram_mapper_read_i           : std_logic;
  signal ram_mapper_write_i          : std_logic;
  signal ram_mapper_address_i        : std_logic_vector(19 downto 0);
  signal ram_mapper_writedata_i      : std_logic_vector(7 downto 0);
  signal ram_mapper_readdata_i       : std_logic_vector(7 downto 0);
  signal ram_mapper_readdatavalid_i  : std_logic;
  signal ram_mapper_waitrequest_i    : std_logic;

  -- Avalon bus: FM-Pack
  signal mem_fmpac_read_i           : std_logic;
  signal mem_fmpac_write_i          : std_logic;
  signal mem_fmpac_address_i        : std_logic_vector(13 downto 0);
  signal mem_fmpac_writedata_i      : std_logic_vector(7 downto 0);
  signal mem_fmpac_readdata_i       : std_logic_vector(7 downto 0);
  signal mem_fmpac_readdatavalid_i  : std_logic;
  signal mem_fmpac_waitrequest_i    : std_logic;
  signal iom_fmpac_write_i          : std_logic;
  signal iom_fmpac_address_i        : std_logic_vector(0 downto 0);
  signal iom_fmpac_writedata_i      : std_logic_vector(7 downto 0);
  signal iom_fmpac_waitrequest_i    : std_logic;
  -- FM-Pac
  signal BCMO       : std_logic_vector(15 downto 0);
  signal BCRO       : std_logic_vector(15 downto 0);
  signal MFL        : std_logic_vector(15 downto 0);
  signal MFR        : std_logic_vector(15 downto 0);
  signal MCL        : std_logic_vector(15 downto 0);
  signal MCR        : std_logic_vector(15 downto 0);
  -- ROM
  signal rom_fmpac_read_i           : std_logic;
  signal rom_fmpac_address_i        : std_logic_vector(13 downto 0);
  signal rom_fmpac_readdata_i       : std_logic_vector(7 downto 0);
  signal rom_fmpac_readdatavalid_i  : std_logic;
  signal rom_fmpac_waitrequest_i    : std_logic;

  -- Avalon bus: SCC
  signal mem_scc_read_i             : std_logic;
  signal mem_scc_write_i            : std_logic;
  signal mem_scc_address_i          : std_logic_vector(15 downto 0);
  signal mem_scc_writedata_i        : std_logic_vector(7 downto 0);
  signal mem_scc_readdata_i         : std_logic_vector(7 downto 0);
  signal mem_scc_readdatavalid_i    : std_logic;
  signal mem_scc_waitrequest_i      : std_logic;
  -- ROM
  signal mem_mega_read_i            : std_logic;
  signal mem_mega_write_i           : std_logic;
  signal mem_mega_address_i         : std_logic_vector(15 downto 0);
  signal mem_mega_writedata_i       : std_logic_vector(7 downto 0);
  signal mem_mega_readdata_i        : std_logic_vector(7 downto 0);
  signal mem_mega_readdatavalid_i   : std_logic;
  signal mem_mega_waitrequest_i     : std_logic;
  -- Audio
  signal scc_amp_i                  : std_logic_vector(10 downto 0);

  -- Avalon bus: IDE
  signal mem_ide_read_i             : std_logic;
  signal mem_ide_write_i            : std_logic;
  signal mem_ide_address_i          : std_logic_vector(13 downto 0);
  signal mem_ide_writedata_i        : std_logic_vector(7 downto 0);
  signal mem_ide_readdata_i         : std_logic_vector(7 downto 0);
  signal mem_ide_readdatavalid_i    : std_logic;
  signal mem_ide_waitrequest_i      : std_logic;
  -- ROM
  signal rom_ide_read_i             : std_logic;
  signal rom_ide_address_i          : std_logic_vector(16 downto 0);
  signal rom_ide_readdata_i         : std_logic_vector(7 downto 0);
  signal rom_ide_readdatavalid_i    : std_logic;
  signal rom_ide_waitrequest_i      : std_logic;

  -- Mega mapper
  signal iom_mega_read_i            : std_logic;
  signal iom_mega_write_i           : std_logic;
  signal iom_mega_address_i         : std_logic_vector(1 downto 0);
  signal iom_mega_writedata_i       : std_logic_vector(7 downto 0);
  signal iom_mega_readdata_i        : std_logic_vector(7 downto 0);
  signal iom_mega_readdatavalid_i   : std_logic;
  signal iom_mega_waitrequest_i     : std_logic;

  -- Audio
  signal audio_ack_i                : std_logic;
  signal audio_output_left_i        : std_logic_vector(15 downto 0);
  signal audio_output_right_i       : std_logic_vector(15 downto 0);

  -- Debug
  signal count                      : unsigned(1 downto 0) := "00";

begin

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
    FREQ_MHZ => 100
  )
  port map
  (
    clk => sysclk,
    pll_locked => locked,
    reset => reset,
    clken1ms => clken1ms_i
  );

  --------------------------------------------------------------------
  -- Clock divider for 3.58 MHz clock
  --------------------------------------------------------------------

  clk3m58_i : process(sysclk, reset)
    variable clock_div_count : integer range 0 to clock_divider_3m58-1;
  begin
    if (reset = '1') then
      clock_div_count := 0;
      clkena_3m58_i <= '0';
    elsif rising_edge(sysclk) then
      if (clock_div_count < clock_divider_3m58-1) then
        clock_div_count := clock_div_count + 1;
        clkena_3m58_i <= '0';
      else
        clock_div_count := 0;
        clkena_3m58_i <= '1';
      end if;
    end if;
  end process;

  --------------------------------------------------------------------
  -- Flash/RAM interface
  --------------------------------------------------------------------

  i_flash_ram_interface : entity work.flash_ram_interface(rtl)
  port map
  (
    -- clock and reset
    clock             => sysclk,
    slot_reset        => slot_reset_i,

    -- avalon slave ports for flash
    mes_port_a_read           => mem_flash_read_i,
    mes_port_a_write          => '0',
    mes_port_a_address        => enable_shadow_ram_i & mem_flash_address_i,
    mes_port_a_writedata      => (others => '0'),
    mes_port_a_readdata       => mem_flash_readdata_i,
    mes_port_a_readdatavalid  => mem_flash_readdatavalid_i,
    mes_port_a_waitrequest    => mem_flash_waitrequest_i,

    -- avalon slave ports for ram
    mes_port_b_read           => mem_ram_read_i,
    mes_port_b_write          => mem_ram_write_i,
    mes_port_b_address        => "100" & mem_ram_address_i,
    mes_port_b_writedata      => mem_ram_writedata_i,
    mes_port_b_readdata       => mem_ram_readdata_i,
    mes_port_b_readdatavalid  => mem_ram_readdatavalid_i,
    mes_port_b_waitrequest    => mem_ram_waitrequest_i,

    -- avalon slave ports for flash+ram
    mes_port_c_read           => mem_flashram_read_i,
    mes_port_c_write          => mem_flashram_write_i,
    mes_port_c_address        => mem_flashram_address_i,
    mes_port_c_writedata      => mem_flashram_writedata_i,
    mes_port_c_readdata       => mem_flashram_readdata_i,
    mes_port_c_readdatavalid  => mem_flashram_readdatavalid_i,
    mes_port_c_waitrequest    => mem_flashram_waitrequest_i,

    -- Parallel flash interface
    pFlAdr    => pFlAdr,
    pFlDat    => pFlDat,
    pFlCS_n   => pFlCS_n,
    pFlOE_n   => pFlOE_n,
    pFlW_n    => pFlW_n,
    pFlRP_n   => pFlRP_n,
    pFlRB_b   => pFlRB_b,
    pFlVpp    => pFlVpp,

    -- SRAM interface
    pRAMCS_n  => pRAMCS_n
  );

  i_flash_layout : work.flash_layout(rtl)
  port map
  (
    -- clock
    clock             => sysclk,
    slot_reset        => slot_reset_i,

    -- Flash memory
    mem_flash_read            => mem_flash_read_i,
    mem_flash_write           => open,
    mem_flash_address         => mem_flash_address_i,
    mem_flash_writedata       => open,
    mem_flash_readdata        => mem_flash_readdata_i,
    mem_flash_readdatavalid   => mem_flash_readdatavalid_i,
    mem_flash_waitrequest     => mem_flash_waitrequest_i,

    -- FM-Pack ROM
    mes_fmpac_read            => rom_fmpac_read_i,
    mes_fmpac_address         => rom_fmpac_address_i,
    mes_fmpac_readdata        => rom_fmpac_readdata_i,
    mes_fmpac_readdatavalid   => rom_fmpac_readdatavalid_i,
    mes_fmpac_waitrequest     => rom_fmpac_waitrequest_i,

    -- IDE ROM
    mes_ide_read              => rom_ide_read_i,
    mes_ide_address           => rom_ide_address_i,
    mes_ide_readdata          => rom_ide_readdata_i,
    mes_ide_readdatavalid     => rom_ide_readdatavalid_i,
    mes_ide_waitrequest       => rom_ide_waitrequest_i
  );

  i_ram_layout : work.ram_layout(rtl)
  port map
  (
    -- clock
    clock                     => sysclk,
    slot_reset                => slot_reset_i,

    -- RAM memory
    mem_ram_read              => mem_ram_read_i,
    mem_ram_write             => mem_ram_write_i,
    mem_ram_address           => mem_ram_address_i,
    mem_ram_writedata         => mem_ram_writedata_i,
    mem_ram_readdata          => mem_ram_readdata_i,
    mem_ram_readdatavalid     => mem_ram_readdatavalid_i,
    mem_ram_waitrequest       => mem_ram_waitrequest_i,

    -- Memory mapper
    mes_mapper_read           => ram_mapper_read_i,
    mes_mapper_write          => ram_mapper_write_i,
    mes_mapper_address        => ram_mapper_address_i,
    mes_mapper_writedata      => ram_mapper_writedata_i,
    mes_mapper_readdata       => ram_mapper_readdata_i,
    mes_mapper_readdatavalid  => ram_mapper_readdatavalid_i,
    mes_mapper_waitrequest    => ram_mapper_waitrequest_i
  );

  --------------------------------------------------------------------
  -- Cartridge slot interface
  --------------------------------------------------------------------

  slot : entity work.card_bus_slave(rtl)
  port map
  (
    -- System Clock
    clock             => sysclk,
    reset             => reset,

    -- MSX-Slot
    slt_reset_n       => pSltRst1_n,
    slt_sltsl_n       => pSltSltsls_n,
    slt_iorq_n        => pSltIorq_n,
    slt_rd_n          => pSltRd_n,
    slt_wr_n          => pSltWr_n,
    slt_addr          => pSltAdr,
    slt_data          => pSltDat,
    slt_bdir_n        => pSltBdir_n,
    slt_wait_n        => pSltWait_n,
    slt_int_n         => pSltInt_n,
    slt_m1_n          => pSltM1_n,
    slt_merq_n        => pSltMerq_n,

    -- Synchronous resets
    slot_reset        => slot_reset_i,
    soft_reset        => soft_reset_i,

    -- Misc
    our_slot          => our_slot_i,

    -- avalon memory master
    mem_address       => mem_address_i,
    mem_write         => mem_write_i,
    mem_writedata     => mem_writedata_i,
    mem_read          => mem_read_i,
    mem_readdata      => mem_readdata_i,
    mem_readdatavalid => mem_readdatavalid_i,
    mem_waitrequest   => mem_waitrequest_i,

    -- avalon io master
    iom_address       => iom_address_i,
    iom_write         => iom_write_i,
    iom_writedata     => iom_writedata_i,
    iom_read          => iom_read_i,
    iom_readdata      => iom_readdata_i,
    iom_readdatavalid => iom_readdatavalid_i,
    iom_waitrequest   => iom_waitrequest_i,

    -- io sniffer
    ism_address      => ism_address_i,
    ism_write        => ism_write_i,
    ism_writedata    => ism_writedata_i,
    ism_waitrequest  => ism_waitrequest_i
  );

  ----------------------------------------------------------------
  -- Keyboard sniffer
  ----------------------------------------------------------------
  key_sniff : entity work.keyboard_sniffer(rtl)
  port map(
    -- Clock and reset
    clock             => sysclk,
    slot_reset        => slot_reset_i,

    -- avalon slave ports for flash    -- io sniffer
    iss_address        => ism_address_i,
    iss_write          => ism_write_i,
    iss_writedata      => ism_writedata_i,
    iss_waitrequest    => ism_waitrequest_i,

    -- Keys
    key_num     => key_num_i,
    key_shift   => key_shift_i,
    key_ctrl    => key_ctrl_i,
    key_graph   => key_graph_i,
    key_code    => key_code_i
  );

  ----------------------------------------------------------------
  -- Configuration manager
  ----------------------------------------------------------------
  i_config_manager : entity work.config_manager(rtl)
  port map(
    -- Clock
    clock             => sysclk,
    slot_reset        => slot_reset_i,
    clken1ms          => clken1ms_i,

    -- Keys
    key_num           => key_num_i,
    key_shift         => key_shift_i,
    key_ctrl          => key_ctrl_i,
    key_graph         => key_graph_i,
    key_code          => key_code_i,

    -- Beep
    beep              => beep_i,

    -- Functions
    enable_ide        => enable_ide_a_i,
    enable_mapper     => enable_mapper_a_i,
    enable_fmpac      => enable_fmpac_a_i,
    enable_scc        => enable_scc_a_i
  );

  --------------------------------------------------------------------
  -- Address decoding
  --------------------------------------------------------------------
  i_address_decoding : entity work.address_decoding(rtl)
  port map
  (
    -- Clock and reset
    clock             => sysclk,
    slot_reset        => slot_reset_i,

    -- Avalon memory slave
    mes_read          => mem_read_i,
    mes_write         => mem_write_i,
    mes_address       => mem_address_i,
    mes_writedata     => mem_writedata_i,
    mes_readdata      => mem_readdata_i,
    mes_readdatavalid => mem_readdatavalid_i,
    mes_waitrequest   => mem_waitrequest_i,

    -- Avalon io slave
    ios_read          => iom_read_i,
    ios_write         => iom_write_i,
    ios_address       => iom_address_i,
    ios_writedata     => iom_writedata_i,
    ios_readdata      => iom_readdata_i,
    ios_readdatavalid => iom_readdatavalid_i,
    ios_waitrequest   => iom_waitrequest_i,

    -- Functions
    test_reg          => open,
    enable_expand     => enable_expand_i,
    enable_ide        => enable_ide_a_i and enable_ide_b_i,
    enable_mapper     => enable_mapper_a_i and enable_mapper_b_i,
    enable_fmpac      => enable_fmpac_a_i and enable_fmpac_b_i,
    enable_scc        => '1',

    -- Memory mapper
    mem_mapper_read          => mem_mapper_read_i,
    mem_mapper_write         => mem_mapper_write_i,
    mem_mapper_address       => mem_mapper_address_i,
    mem_mapper_writedata     => mem_mapper_writedata_i,
    mem_mapper_readdata      => mem_mapper_readdata_i,
    mem_mapper_readdatavalid => mem_mapper_readdatavalid_i,
    mem_mapper_waitrequest   => mem_mapper_waitrequest_i,
    iom_mapper_read          => iom_mapper_read_i,
    iom_mapper_write         => iom_mapper_write_i,
    iom_mapper_address       => iom_mapper_address_i,
    iom_mapper_writedata     => iom_mapper_writedata_i,
    iom_mapper_readdata      => iom_mapper_readdata_i,
    iom_mapper_readdatavalid => iom_mapper_readdatavalid_i,
    iom_mapper_waitrequest   => iom_mapper_waitrequest_i,

    -- IDE
    mem_ide_read             => mem_ide_read_i,
    mem_ide_write            => mem_ide_write_i,
    mem_ide_address          => mem_ide_address_i,
    mem_ide_writedata        => mem_ide_writedata_i,
    mem_ide_readdata         => mem_ide_readdata_i,
    mem_ide_readdatavalid    => mem_ide_readdatavalid_i,
    mem_ide_waitrequest      => mem_ide_waitrequest_i,

    -- FM-Pack
    mem_fmpac_read           => mem_fmpac_read_i,
    mem_fmpac_write          => mem_fmpac_write_i,
    mem_fmpac_address        => mem_fmpac_address_i,
    mem_fmpac_writedata      => mem_fmpac_writedata_i,
    mem_fmpac_readdata       => mem_fmpac_readdata_i,
    mem_fmpac_readdatavalid  => mem_fmpac_readdatavalid_i,
    mem_fmpac_waitrequest    => mem_fmpac_waitrequest_i,
    iom_fmpac_write          => iom_fmpac_write_i,
    iom_fmpac_address        => iom_fmpac_address_i,
    iom_fmpac_writedata      => iom_fmpac_writedata_i,
    iom_fmpac_waitrequest    => iom_fmpac_waitrequest_i,

    -- SCC
    mem_scc_read             => mem_scc_read_i,
    mem_scc_write            => mem_scc_write_i,
    mem_scc_address          => mem_scc_address_i,
    mem_scc_writedata        => mem_scc_writedata_i,
    mem_scc_readdata         => mem_scc_readdata_i,
    mem_scc_readdatavalid    => mem_scc_readdatavalid_i,
    mem_scc_waitrequest      => mem_scc_waitrequest_i,

    -- Mega mapper (I/O #f0)
    iom_mega_read            => iom_mega_read_i,
    iom_mega_write           => iom_mega_write_i,
    iom_mega_address         => iom_mega_address_i,
    iom_mega_writedata       => iom_mega_writedata_i,
    iom_mega_readdata        => iom_mega_readdata_i,
    iom_mega_readdatavalid   => iom_mega_readdatavalid_i,
    iom_mega_waitrequest     => iom_mega_waitrequest_i
  );

  ----------------------------------------------------------------
  -- Memory mapper (1MB)
  ----------------------------------------------------------------

  i_memory_mapper : entity work.memory_mapper(rtl)
  port map
  (
    -- clock and reset
    clock             => sysclk,
    slot_reset        => slot_reset_i,

    -- Avalon slave ports
    mes_mapper_read           => mem_mapper_read_i,
    mes_mapper_write          => mem_mapper_write_i,
    mes_mapper_address        => mem_mapper_address_i,
    mes_mapper_writedata      => mem_mapper_writedata_i,
    mes_mapper_readdata       => mem_mapper_readdata_i,
    mes_mapper_readdatavalid  => mem_mapper_readdatavalid_i,
    mes_mapper_waitrequest    => mem_mapper_waitrequest_i,
    ios_mapper_read           => iom_mapper_read_i,
    ios_mapper_write          => iom_mapper_write_i,
    ios_mapper_address        => iom_mapper_address_i,
    ios_mapper_writedata      => iom_mapper_writedata_i,
    ios_mapper_readdata       => iom_mapper_readdata_i,
    ios_mapper_readdatavalid  => iom_mapper_readdatavalid_i,
    ios_mapper_waitrequest    => iom_mapper_waitrequest_i,

    -- RAM master port
    ram_mapper_read           => ram_mapper_read_i,
    ram_mapper_write          => ram_mapper_write_i,
    ram_mapper_address        => ram_mapper_address_i,
    ram_mapper_writedata      => ram_mapper_writedata_i,
    ram_mapper_readdata       => ram_mapper_readdata_i,
    ram_mapper_readdatavalid  => ram_mapper_readdatavalid_i,
    ram_mapper_waitrequest    => ram_mapper_waitrequest_i
  );

  ----------------------------------------------------------------
  -- FM-PAC
  ----------------------------------------------------------------

  i_fmpac : entity work.fmpac(rtl)
  port map
  (
    -- clock and reset
    clock             => sysclk,
    slot_reset        => slot_reset_i,
    clkena_3m58       => clkena_3m58_i,

    -- Avalon slave ports
    mes_fmpac_read           => mem_fmpac_read_i,
    mes_fmpac_write          => mem_fmpac_write_i,
    mes_fmpac_address        => mem_fmpac_address_i,
    mes_fmpac_writedata      => mem_fmpac_writedata_i,
    mes_fmpac_readdata       => mem_fmpac_readdata_i,
    mes_fmpac_readdatavalid  => mem_fmpac_readdatavalid_i,
    mes_fmpac_waitrequest    => mem_fmpac_waitrequest_i,
    ios_fmpac_write          => iom_fmpac_write_i,
    ios_fmpac_address        => iom_fmpac_address_i,
    ios_fmpac_writedata      => iom_fmpac_writedata_i,
    ios_fmpac_waitrequest    => iom_fmpac_waitrequest_i,

    -- rom master port
    rom_fmpac_read           => rom_fmpac_read_i,
    rom_fmpac_address        => rom_fmpac_address_i,
    rom_fmpac_readdata       => rom_fmpac_readdata_i,
    rom_fmpac_readdatavalid  => rom_fmpac_readdatavalid_i,
    rom_fmpac_waitrequest    => rom_fmpac_waitrequest_i,

    -- Audio output
    BCMO    => BCMO,
    BCRO    => BCRO,
    SDO     => open
  );

  ----------------------------------------------------------------
  -- SCC
  ----------------------------------------------------------------

  i_scc : entity work.scc(rtl)
  port map
  (
    -- clock and reset
    clock                 => sysclk,
    slot_reset            => slot_reset_i,
    clkena_3m58           => clkena_3m58_i,

    -- Configuration
    SccEna                => enable_scc_a_i and enable_scc_b_i,

    -- Avalon slave ports
    mes_scc_read          => mem_scc_read_i,
    mes_scc_write         => mem_scc_write_i,
    mes_scc_address       => mem_scc_address_i,
    mes_scc_writedata     => mem_scc_writedata_i,
    mes_scc_readdata      => mem_scc_readdata_i,
    mes_scc_readdatavalid => mem_scc_readdatavalid_i,
    mes_scc_waitrequest   => mem_scc_waitrequest_i,
    -- avalon master port
    mem_scc_read          => mem_mega_read_i,
    mem_scc_write         => mem_mega_write_i,
    mem_scc_address       => mem_mega_address_i,
    mem_scc_writedata     => mem_mega_writedata_i,
    mem_scc_readdata      => mem_mega_readdata_i,
    mem_scc_readdatavalid => mem_mega_readdatavalid_i,
    mem_scc_waitrequest   => mem_mega_waitrequest_i,

    -- SCC mode registers
    EseScc_MA19            => EseScc_MA19_i,
    EseScc_MA20            => EseScc_MA20_i,
    SccPlus_Enable         => SccPlus_Enable_i,
    SccPlus_AllRam         => SccPlus_AllRam_i,
    SccPlus_B0Ram          => SccPlus_B0Ram_i,
    SccPlus_B1Ram          => SccPlus_B1Ram_i,
    SccPlus_B2Ram          => SccPlus_B2Ram_i,

    -- Audio output
    SccAmp    => scc_amp_i
  );


  ----------------------------------------------------------------
  -- mega-ram like mapper
  ----------------------------------------------------------------

  i_mega_ram : entity work.mega_ram(rtl)
  port map
  (
    -- clock and reset
    clock                  => sysclk,
    slot_reset             => slot_reset_i,
    soft_reset             => soft_reset_i,

    -- Functions
    enable_expand          => enable_expand_i,
    enable_ide             => enable_ide_b_i,
    enable_mapper          => enable_mapper_b_i,
    enable_fmpac           => enable_fmpac_b_i,
    enable_scc             => enable_scc_b_i,

    -- EEPROM
    EECS                   => EECS,
    EECK                   => EECK,
    EEDI                   => EEDI,
    EEDO                   => EEDO,

    -- Misc
    our_slot               => our_slot_i,
    enable_shadow_ram      => enable_shadow_ram_i,

    -- SCC mode registers
    EseScc_MA19            => EseScc_MA19_i,
    EseScc_MA20            => EseScc_MA20_i,
    SccPlus_Enable         => SccPlus_Enable_i,
    SccPlus_AllRam         => SccPlus_AllRam_i,
    SccPlus_B0Ram          => SccPlus_B0Ram_i,
    SccPlus_B1Ram          => SccPlus_B1Ram_i,
    SccPlus_B2Ram          => SccPlus_B2Ram_i,

    -- avalon slave port
    mes_mega_read          => mem_mega_read_i,
    mes_mega_write         => mem_mega_write_i,
    mes_mega_address       => mem_mega_address_i,
    mes_mega_writedata     => mem_mega_writedata_i,
    mes_mega_readdata      => mem_mega_readdata_i,
    mes_mega_readdatavalid => mem_mega_readdatavalid_i,
    mes_mega_waitrequest   => mem_mega_waitrequest_i,
    -- 0xf0
    ios_mega_read          => iom_mega_read_i,
    ios_mega_write         => iom_mega_write_i,
    ios_mega_address       => iom_mega_address_i,
    ios_mega_writedata     => iom_mega_writedata_i,
    ios_mega_readdata      => iom_mega_readdata_i,
    ios_mega_readdatavalid => iom_mega_readdatavalid_i,
    ios_mega_waitrequest   => iom_mega_waitrequest_i,

    -- avalon master port
    mem_mega_read          => mem_flashram_read_i,
    mem_mega_write         => mem_flashram_write_i,
    mem_mega_address       => mem_flashram_address_i,
    mem_mega_writedata     => mem_flashram_writedata_i,
    mem_mega_readdata      => mem_flashram_readdata_i,
    mem_mega_readdatavalid => mem_flashram_readdatavalid_i,
    mem_mega_waitrequest   => mem_flashram_waitrequest_i
  );

  ----------------------------------------------------------------
  -- IDE
  ----------------------------------------------------------------

  i_ide : entity work.ide(rtl)
  port map
  (
    -- clock and reset
    clock                 => sysclk,
    slot_reset            => slot_reset_i,

    -- Avalon slave ports
    mes_ide_read          => mem_ide_read_i,
    mes_ide_write         => mem_ide_write_i,
    mes_ide_address       => mem_ide_address_i,
    mes_ide_writedata     => mem_ide_writedata_i,
    mes_ide_readdata      => mem_ide_readdata_i,
    mes_ide_readdatavalid => mem_ide_readdatavalid_i,
    mes_ide_waitrequest   => mem_ide_waitrequest_i,

    -- rom master port
    rom_ide_read          => rom_ide_read_i,
    rom_ide_address       => rom_ide_address_i,
    rom_ide_readdata      => rom_ide_readdata_i,
    rom_ide_readdatavalid => rom_ide_readdatavalid_i,
    rom_ide_waitrequest   => rom_ide_waitrequest_i,

    -- CF card interface
    pIDEAdr               => pIDEAdr,
    pIDEDat               => pIDEDat,
    pIDECS1_n             => pIDECS1_n,
    pIDECS3_n             => pIDECS3_n,
    pIDERD_n              => pIDERD_n,
    pIDEWR_n              => pIDEWR_n,
    pPIN180               => pPIN180,
    pIDE_Rst_n            => pIDE_Rst_n
  );

  ----------------------------------------------------------------
  -- Audio Mixer
  ----------------------------------------------------------------

  VMFL : entity work.sample_volume(rtl)
  port map(
    clock => sysclk,
    sin16 => BCMO,
    sout16 => MFL,
    level => LVF
  );
  
  VMFR : entity work.sample_volume(rtl)
  port map (
    clock => sysclk,
    sin16 => BCRO,
    sout16 => MFR,
    level => LVF
  );

  VMSL : entity work.sample_volume(rtl)
  port map(
    clock => sysclk,
    sin16 => std_logic_vector(signed(MFL) + signed(scc_amp_i & scc_amp_i(10) & scc_amp_i(10) & scc_amp_i(10) & scc_amp_i(10) & scc_amp_i(10))),
    sout16 => MCL,
    level => LVF
  );
  
  VMSR : entity work.sample_volume(rtl)
  port map (
    clock => sysclk,
    sin16 => std_logic_vector(signed(MFR) + signed(scc_amp_i & scc_amp_i(10) & scc_amp_i(10) & scc_amp_i(10) & scc_amp_i(10) & scc_amp_i(10))),
    sout16 => MCR,
    level => LVF
  );

  --------------------------------------------------------------------
  -- Waveform generator
  --------------------------------------------------------------------

  i_waveform_generator_left : entity work.waveform_generator(rtl)
  port map
  (
    clk => sysclk,
    reset => reset,
    audio_strobe => audio_ack_i,
    tone_enable => beep_i,
    tone_select => '1',
    audio_input => MCL,
    audio_output => audio_output_left_i
  );

  i_waveform_generator_right : entity work.waveform_generator(rtl)
  port map
  (
    clk => sysclk,
    reset => reset,
    audio_strobe => audio_ack_i,
    tone_enable => beep_i,
    tone_select => '1',
    audio_input => MCR,
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

end rtl;
