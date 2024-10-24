----------------------------------------------------------------
-- Carnivore toplevel
----------------------------------------------------------------
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

  -- Clock divider for 3.58 MHz clock
  signal clkena_3m58_i  : std_logic;

  -- Avalon memory master
  signal mem_read_i           : std_logic;
  signal mem_write_i          : std_logic;
  signal mem_address_i        : std_logic_vector(15 downto 0);
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

  -- Synchronous reset
  signal slot_reset_i         : std_logic;

  -- Flash avalon slave port
  signal mem_flash_read_i           : std_logic;
  signal mem_flash_write_i          : std_logic;
  signal mem_flash_address_i        : std_logic_vector(22 downto 0);
  signal mem_flash_writedata_i      : std_logic_vector(7 downto 0);
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
  -- ROM
  signal rom_fmpac_read_i           : std_logic;
  signal rom_fmpac_address_i        : std_logic_vector(13 downto 0);
  signal rom_fmpac_readdata_i       : std_logic_vector(7 downto 0);
  signal rom_fmpac_readdatavalid_i  : std_logic;
  signal rom_fmpac_waitrequest_i    : std_logic;

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

  -- Audio
  signal audio_output_left_i : std_logic_vector(15 downto 0);
  signal audio_output_right_i : std_logic_vector(15 downto 0);

  -- Debug
  signal count : unsigned(1 downto 0) := "00";

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

  -- EEPROM
  EECS <= '1';
  EECK <= '0';
  EEDI <= '0';

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
    clken1ms => open
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
  -- Flash interface
  --------------------------------------------------------------------

  i_flash_ram_interface : entity work.flash_ram_interface(rtl)
  port map
  (
    -- clock and reset
    clock             => sysclk,
    slot_reset        => slot_reset_i,

    -- avalon slave ports for flash
    mes_flash_read           => mem_flash_read_i,
    mes_flash_write          => mem_flash_write_i,
    mes_flash_address        => mem_flash_address_i,
    mes_flash_writedata      => mem_flash_writedata_i,
    mes_flash_readdata       => mem_flash_readdata_i,
    mes_flash_readdatavalid  => mem_flash_readdatavalid_i,
    mes_flash_waitrequest    => mem_flash_waitrequest_i,

    -- avalon slave ports for ram
    mes_ram_read             => mem_ram_read_i,
    mes_ram_write            => mem_ram_write_i,
    mes_ram_address          => mem_ram_address_i,
    mes_ram_writedata        => mem_ram_writedata_i,
    mes_ram_readdata         => mem_ram_readdata_i,
    mes_ram_readdatavalid    => mem_ram_readdatavalid_i,
    mes_ram_waitrequest      => mem_ram_waitrequest_i,

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
    mem_flash_write           => mem_flash_write_i,
    mem_flash_address         => mem_flash_address_i,
    mem_flash_writedata       => mem_flash_writedata_i,
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

    -- Synchronous reset
    slot_reset        => slot_reset_i,

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
    iom_waitrequest   => iom_waitrequest_i
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

    -- IDE
    mem_ide_read             => mem_ide_read_i,
    mem_ide_write            => mem_ide_write_i,
    mem_ide_address          => mem_ide_address_i,
    mem_ide_writedata        => mem_ide_writedata_i,
    mem_ide_readdata         => mem_ide_readdata_i,
    mem_ide_readdatavalid    => mem_ide_readdatavalid_i,
    mem_ide_waitrequest      => mem_ide_waitrequest_i
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

  audio_output_left_i <= MFL;
  audio_output_right_i <= MFR;

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
    audio_ack => open,
    i2s_mclk => dac_sck,
    i2s_lrclk => dac_lrck,
    i2s_sclk => dac_bck,
    i2s_data => dac_din
  );

end rtl;
