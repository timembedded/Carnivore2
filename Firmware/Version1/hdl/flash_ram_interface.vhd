----------------------------------------------------------------
-- Flash and SRAM interface
----------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity flash_ram_interface is
port(
  -- clock and reset
  clock       : in std_logic;
  slot_reset  : in std_logic;

  -- avalon slave ports for flash
  mes_flash_read          : in std_logic;
  mes_flash_write         : in std_logic;
  mes_flash_address       : in std_logic_vector(22 downto 0);
  mes_flash_writedata     : in std_logic_vector(7 downto 0);
  mes_flash_readdata      : out std_logic_vector(7 downto 0);
  mes_flash_readdatavalid : out std_logic;
  mes_flash_waitrequest   : out std_logic;

  -- avalon slave ports for ram
  mes_ram_read            : in std_logic;
  mes_ram_write           : in std_logic;
  mes_ram_address         : in std_logic_vector(20 downto 0);
  mes_ram_writedata       : in std_logic_vector(7 downto 0);
  mes_ram_readdata        : out std_logic_vector(7 downto 0);
  mes_ram_readdatavalid   : out std_logic;
  mes_ram_waitrequest     : out std_logic;

  -- Parallel flash interface
  pFlAdr    : OUT std_logic_vector(22 downto 0);
  pFlDat    : INOUT std_logic_vector(7 downto 0);
  pFlCS_n   : OUT std_logic;
  pFlOE_n   : OUT std_logic;
  pFlW_n    : OUT std_logic;
  pFlRP_n   : OUT std_logic;
  pFlRB_b   : IN std_logic;
  pFlVpp    : OUT std_logic;

  -- SRAM interface
  pRAMCS_n  : OUT std_logic
);
end flash_ram_interface;

architecture rtl of flash_ram_interface is

  constant FLASH_CYCLE_TIME : integer := 8; -- 80ns
  constant RAM_CYCLE_TIME   : integer := 6; -- 60ns

  signal delay_time_x, delay_time_r : integer range 0 to FLASH_CYCLE_TIME-1;

  type state_t is (S_IDLE, S_FLASH_READ, S_FLASH_WRITE, S_RAM_READ, S_RAM_WRITE);
  signal state_x, state_r : state_t;

  signal flram_address_x, flram_address_r     : std_logic_vector(22 downto 0);
  signal flram_writedata_x, flram_writedata_r : std_logic_vector(7 downto 0);
  signal flram_output_enable_x, flram_output_enable_r : std_logic;
  signal flram_flash_select_x, flram_flash_select_r : std_logic;
  signal flram_ram_select_x, flram_ram_select_r : std_logic;
  signal flram_read_x, flram_read_r           : std_logic;
  signal flram_write_x, flram_write_r         : std_logic;

  signal mes_latch_data_x, mes_latch_data_r   : std_logic;
  signal mes_readdata_r                       : std_logic_vector(7 downto 0);
  signal mes_flash_datavalid_x, mes_flash_datavalid_r : std_logic;
  signal mes_ram_datavalid_x, mes_ram_datavalid_r : std_logic;

begin

  pFlDat <= flram_writedata_r when flram_output_enable_r = '1' else (others => 'Z');
  pFlAdr <= flram_address_r;
  pFlCS_n <= not flram_flash_select_r;
  pRAMCS_n <= not flram_ram_select_r;
  pFlOE_n <= not flram_read_r;
  pFlW_n <= not flram_write_r;
  pFlRP_n <= '1';
  pFlVpp <= '0';

  -- Data input register
  -- Note: Make sure this is a 'fast input register'
  process(clock)
  begin
    if rising_edge(clock) then
      if (mes_latch_data_r = '1') then
        mes_readdata_r <= pFlDat;
      end if;
    end if;
  end process;


  --------------------------------------------------------
  -- 
  --------------------------------------------------------

  mes_flash_readdatavalid <= mes_flash_datavalid_r;
  mes_flash_readdata <= mes_readdata_r;
  mes_ram_readdatavalid <= mes_ram_datavalid_r;
  mes_ram_readdata <= mes_readdata_r;

  process(all)
  begin
    state_x <= state_r;
    delay_time_x <= delay_time_r;

    flram_output_enable_x <= '0';
    flram_flash_select_x <= '0';
    flram_ram_select_x <= '0';
    flram_read_x <= '0';
    flram_write_x <= '0';
    flram_address_x <= flram_address_r;
    flram_writedata_x <= flram_writedata_r;

    mes_flash_datavalid_x <= '0';
    mes_ram_datavalid_x <= '0';

    mes_flash_waitrequest <= '1';
    mes_ram_waitrequest <= '1';

    mes_latch_data_x <= '0';

    case (state_r) is
      when S_IDLE =>
        -- Any transfer requested?
        if (mes_ram_read = '1') then
          mes_ram_waitrequest <= '0';
          flram_ram_select_x <= '1';
          flram_read_x <= '1';
          flram_address_x <= "00" & mes_ram_address;
          delay_time_x <= RAM_CYCLE_TIME-1;
          state_x <= S_RAM_READ;
        elsif (mes_ram_write = '1') then
          mes_ram_waitrequest <= '0';
          flram_ram_select_x <= '1';
          flram_output_enable_x <= '1';
          flram_address_x <= "00" & mes_ram_address;
          flram_writedata_x <= mes_ram_writedata;
          delay_time_x <= RAM_CYCLE_TIME-1;
          state_x <= S_RAM_WRITE;
        elsif (mes_flash_read = '1') then
          mes_flash_waitrequest <= '0';
          flram_flash_select_x <= '1';
          flram_read_x <= '1';
          flram_address_x <= mes_flash_address;
          delay_time_x <= FLASH_CYCLE_TIME-1;
          state_x <= S_FLASH_READ;
        elsif (mes_flash_write = '1') then
          mes_flash_waitrequest <= '0';
          flram_flash_select_x <= '1';
          flram_output_enable_x <= '1';
          flram_address_x <= mes_flash_address;
          flram_writedata_x <= mes_flash_writedata;
          delay_time_x <= FLASH_CYCLE_TIME-1;
          state_x <= S_FLASH_WRITE;
        end if;

      when S_FLASH_READ =>
        -- Process read
        flram_flash_select_x <= '1';
        flram_read_x <= '1';
        if (delay_time_r /= 0) then
          if (delay_time_r = 1) then
            mes_latch_data_x <= '1';
          end if;
          delay_time_x <= delay_time_r - 1;
        else
          mes_flash_datavalid_x <= '1';
          state_x <= S_IDLE;
        end if;
 
      when S_FLASH_WRITE =>
        -- Process write
        flram_flash_select_x <= '1';
        flram_output_enable_x <= '1';
        flram_write_x <= '1';
        if (delay_time_r /= 0) then
          delay_time_x <= delay_time_r - 1;
        else
          state_x <= S_IDLE;
        end if;

      when S_RAM_READ =>
        -- Process read
        flram_ram_select_x <= '1';
        flram_read_x <= '1';
        if (delay_time_r /= 0) then
          if (delay_time_r = 1) then
            mes_latch_data_x <= '1';
          end if;
          delay_time_x <= delay_time_r - 1;
        else
          mes_ram_datavalid_x <= '1';
          state_x <= S_IDLE;
        end if;
 
      when S_RAM_WRITE =>
        -- Process write
        flram_ram_select_x <= '1';
        flram_output_enable_x <= '1';
        flram_write_x <= '1';
        if (delay_time_r /= 0) then
          delay_time_x <= delay_time_r - 1;
        else
          state_x <= S_IDLE;
        end if;
 
    end case;
  end process;

  --------------------------------------------------------
  -- Registers
  --------------------------------------------------------
  process(clock)
  begin
    if rising_edge(clock) then
      if (slot_reset = '1') then
        state_r <= S_IDLE;
        flram_flash_select_r <= '0';
        flram_ram_select_r <= '0';
      else
        state_r <= state_x;
        flram_flash_select_r <= flram_flash_select_x;
        flram_ram_select_r <= flram_ram_select_x;
      end if;

      delay_time_r <= delay_time_x;

      flram_address_r <= flram_address_x;
      flram_writedata_r <= flram_writedata_x;
      flram_output_enable_r <= flram_output_enable_x;
      flram_read_r <= flram_read_x;
      flram_write_r <= flram_write_x;

      mes_latch_data_r <= mes_latch_data_x;
      mes_flash_datavalid_r <= mes_flash_datavalid_x;
      mes_ram_datavalid_r <= mes_ram_datavalid_x;
    end if;
  end process;

end rtl;

  