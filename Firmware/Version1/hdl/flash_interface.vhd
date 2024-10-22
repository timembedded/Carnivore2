----------------------------------------------------------------
-- Flash interface
----------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity flash_interface is
port(
  -- clock and reset
  clock       : in std_logic;
  slot_reset  : in std_logic;

  -- avalon slave ports
  mes_flash_read           : in std_logic;
  mes_flash_write          : in std_logic;
  mes_flash_address        : in std_logic_vector(22 downto 0);
  mes_flash_writedata      : in std_logic_vector(7 downto 0);
  mes_flash_readdata       : out std_logic_vector(7 downto 0);
  mes_flash_readdatavalid  : out std_logic;
  mes_flash_waitrequest    : out std_logic;

  -- Parallel flash interface
  pFlAdr    : OUT std_logic_vector(22 downto 0);
  pFlDat    : INOUT std_logic_vector(7 downto 0);
  pFlCS_n   : OUT std_logic;
  pFlOE_n   : OUT std_logic;
  pFlW_n    : OUT std_logic;
  pFlRP_n   : OUT std_logic;
  pFlRB_b   : IN std_logic;
  pFlVpp    : OUT std_logic
);
end flash_interface;

architecture rtl of flash_interface is

  constant READ_DELAY_TIME : integer := 8; -- 80ns

  signal delay_time_x, delay_time_r : integer range 0 to READ_DELAY_TIME-1;

  type state_t is (S_IDLE, S_READ, S_WRITE);
  signal state_x, state_r : state_t;

  signal flash_address_x, flash_address_r     : std_logic_vector(22 downto 0);
  signal flash_writedata_x, flash_writedata_r : std_logic_vector(7 downto 0);
  signal flash_output_enable_x, flash_output_enable_r : std_logic;
  signal flash_chip_select_x, flash_chip_select_r : std_logic;
  signal flash_read_x, flash_read_r           : std_logic;
  signal flash_write_x, flash_write_r         : std_logic;

  signal mes_latch_data_x, mes_latch_data_r   : std_logic;
  signal mes_readdata_r                       : std_logic_vector(7 downto 0);
  signal mes_readdatavalid_x, mes_readdatavalid_r : std_logic;

begin

  pFlDat <= flash_writedata_r when flash_output_enable_r = '1' else (others => 'Z');
  pFlAdr <= flash_address_r;
  pFlCS_n <= not flash_chip_select_r;
  pFlOE_n <= not flash_read_r;
  pFlW_n <= not flash_write_r;
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

  mes_flash_readdatavalid <= mes_readdatavalid_r;
  mes_flash_readdata <= mes_readdata_r;

  process(all)
  begin
    state_x <= state_r;
    delay_time_x <= delay_time_r;

    flash_output_enable_x <= '0';
    flash_chip_select_x <= '0';
    flash_read_x <= '0';
    flash_write_x <= '0';
    flash_address_x <= flash_address_r;
    flash_writedata_x <= flash_writedata_r;

    mes_readdatavalid_x <= '0';

    mes_flash_waitrequest <= '1';
    mes_latch_data_x <= '0';

    case (state_r) is
      when S_IDLE =>
        -- Only accept transfers in this state
        mes_flash_waitrequest <= '0';
        -- Any transfer requested?
        if (mes_flash_read = '1') then
          flash_chip_select_x <= '1';
          flash_read_x <= '1';
          flash_address_x <= mes_flash_address;
          state_x <= S_READ;
        elsif (mes_flash_write = '1') then
          flash_chip_select_x <= '1';
          flash_output_enable_x <= '1';
          flash_address_x <= mes_flash_address;
          flash_writedata_x <= mes_flash_writedata;
          state_x <= S_WRITE;
        end if;
        delay_time_x <= READ_DELAY_TIME-1;

      when S_READ =>
        -- Process read
        flash_chip_select_x <= '1';
        flash_read_x <= '1';
        if (delay_time_r /= 0) then
          if (delay_time_r = 1) then
            mes_latch_data_x <= '1';
          end if;
          delay_time_x <= delay_time_r - 1;
        else
          mes_readdatavalid_x <= '1';
          state_x <= S_IDLE;
        end if;
 
      when S_WRITE =>
        -- Process write
        flash_chip_select_x <= '1';
        flash_output_enable_x <= '1';
        flash_write_x <= '1';
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
        flash_output_enable_r <= '0';
        flash_chip_select_r <= '0';
        flash_read_r <= '0';
        flash_write_r <= '0';
      else
        state_r <= state_x;
        flash_output_enable_r <= flash_output_enable_x;
        flash_chip_select_r <= flash_chip_select_x;
        flash_read_r <= flash_read_x;
        flash_write_r <= flash_write_x;
      end if;

      delay_time_r <= delay_time_x;

      flash_address_r <= flash_address_x;
      flash_writedata_r <= flash_writedata_x;

      mes_latch_data_r <= mes_latch_data_x;
      mes_readdatavalid_r <= mes_readdatavalid_x;
    end if;
  end process;

end rtl;

  