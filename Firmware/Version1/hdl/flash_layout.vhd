----------------------------------------------------------------
-- Flash layout
----------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity flash_layout is
  port(
    -- clock
    clock       : IN std_logic;
    slot_reset  : IN std_logic;

    -- Flash memory
    mem_flash_read            : out std_logic;
    mem_flash_write           : out std_logic;
    mem_flash_address         : out std_logic_vector(22 downto 0);
    mem_flash_writedata       : out std_logic_vector(7 downto 0);
    mem_flash_readdata        : in std_logic_vector(7 downto 0);
    mem_flash_readdatavalid   : in std_logic;
    mem_flash_waitrequest     : in std_logic;

    -- FM-Pack ROM
    mes_fmpac_read            : in std_logic;
    mes_fmpac_address         : in std_logic_vector(13 downto 0);
    mes_fmpac_readdata        : out std_logic_vector(7 downto 0);
    mes_fmpac_readdatavalid   : out std_logic;
    mes_fmpac_waitrequest     : out std_logic;

    -- IDE ROM
    mes_ide_read              : in std_logic;
    mes_ide_address           : in std_logic_vector(16 downto 0);
    mes_ide_readdata          : out std_logic_vector(7 downto 0);
    mes_ide_readdatavalid     : out std_logic;
    mes_ide_waitrequest       : out std_logic
);
end flash_layout;

architecture rtl of flash_layout is

  -- chipselect
  type select_t is (SEL_FMPAC, SEL_IDE, SEL_NONE);
  signal select_r, select_x : select_t;

begin

  mes_fmpac_readdata <= mem_flash_readdata;
  mes_fmpac_readdatavalid <= '1' when mem_flash_readdatavalid = '1' and select_r = SEL_FMPAC else '0';

  mes_ide_readdata <= mem_flash_readdata;
  mes_ide_readdatavalid <= '1' when mem_flash_readdatavalid = '1' and select_r = SEL_IDE else '0';

  -- At the moment nothing writes to flash
  mem_flash_write <= '0';
  mem_flash_writedata <= (others => '0');

  --------------------------------------------------------------------
  -- Select slave
  --------------------------------------------------------------------
  process(all)
  begin
    mem_flash_read <= '0';
    mem_flash_address <= (others => '-');
    select_x <= select_r;

    mes_fmpac_waitrequest <= '1';
    mes_ide_waitrequest <= '1';

    -- Select slave to read
    if (mes_fmpac_read = '1' and select_r = SEL_NONE and mem_flash_waitrequest = '0') then
      -- FM-PAC
      select_x <= SEL_FMPAC;
      mem_flash_read <= '1';
      mem_flash_address <= "000"&"0011"&"00" & mes_fmpac_address;
      mes_fmpac_waitrequest <= '0';
    elsif (mes_ide_read = '1' and select_r = SEL_NONE and mem_flash_waitrequest = '0') then
      -- IDE
      select_x <= SEL_IDE;
      mem_flash_read <= '1';
      if (mes_ide_address(16) = '0') then
        mem_flash_address <= "000"&"0001"& mes_ide_address(15 downto 0);
      else
        mem_flash_address <= "000"&"0010"& mes_ide_address(15 downto 0);
      end if;
      mes_ide_waitrequest <= '0';
    elsif (mem_flash_readdatavalid = '1') then
      select_x <= SEL_NONE;
    end if;
  end process;

  --------------------------------------------------------------------
  -- Registers
  --------------------------------------------------------------------
  process(clock)
  begin
    if rising_edge(clock) then
      if (slot_reset = '1') then
        -- chipselect
        select_r <= SEL_NONE;
      else
        -- chipselect
        select_r <= select_x;
      end if;
    end if;
  end process;

end rtl;
