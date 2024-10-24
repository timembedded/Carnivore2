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
  type mes_cs_t is (MES_CS_FMPAC, MES_CS_IDE, MES_CS_NONE);
  signal mes_cs_i : mes_cs_t;
  signal mes_cs_read_r, mes_cs_read_x : mes_cs_t;

begin

  --------------------------------------------------------------------
  -- Arbiter
  --------------------------------------------------------------------

  arbiter : process(all)
  begin
    if (mes_fmpac_read = '1') then
      -- FM-PAC
      mes_cs_i <= MES_CS_FMPAC;
    elsif (mes_ide_read = '1') then
      -- IDE
      mes_cs_i <= MES_CS_IDE;
    else
      mes_cs_i <= MES_CS_NONE;
    end if;
  end process;

  --------------------------------------------------------------------
  -- Read and write
  --------------------------------------------------------------------
  mem_read_write: process(all)
  begin
    mem_flash_read <= '0';
    mem_flash_write <= '0';
    mem_flash_writedata <= (others => '-');
    mem_flash_address <= (others => '-');

    -- Read signal and waitrequest
    mes_fmpac_waitrequest <= '1';
    mes_ide_waitrequest <= '1';
    case (mes_cs_i) is
      when MES_CS_FMPAC =>
        -- FM-PAC
        mem_flash_read <= mes_fmpac_read;
        mem_flash_address <= "000"&"0011"&"00" & mes_fmpac_address;
        mes_fmpac_waitrequest <= mem_flash_waitrequest;
      when MES_CS_IDE =>
        -- IDE
        mem_flash_read <= mes_ide_read;
        if (mes_ide_address(16) = '0') then
          mem_flash_address <= "000"&"0001"& mes_ide_address(15 downto 0);
        else
          mem_flash_address <= "000"&"0010"& mes_ide_address(15 downto 0);
        end if;
        mes_ide_waitrequest <= mem_flash_waitrequest;
      when others =>
    end case;

    -- Read chipselect state
    if (mes_cs_i /= MES_CS_NONE and mem_flash_waitrequest = '0') then
      mes_cs_read_x <= mes_cs_i;
    elsif (mem_flash_readdatavalid = '1') then
      -- return data, can accept new transfer next clock
      mes_cs_read_x <= MES_CS_NONE;
    else
      -- no active chipselect, keep current state
      mes_cs_read_x <= mes_cs_read_r;
    end if;

    -- Read de-multiplexer
    mes_fmpac_readdata <= mem_flash_readdata;
    mes_fmpac_readdatavalid <= '0';
    mes_ide_readdata <= mem_flash_readdata;
    mes_ide_readdatavalid <= '0';
    case (mes_cs_read_r) is
      when MES_CS_FMPAC =>
        -- FM-PAC
        mes_fmpac_readdatavalid <= mem_flash_readdatavalid;
      when MES_CS_IDE =>
        -- IDE
        mes_ide_readdatavalid <= mem_flash_readdatavalid;
      when others =>
    end case;
  end process;

  --------------------------------------------------------------------
  -- Registers
  --------------------------------------------------------------------
  process(clock)
  begin
    if rising_edge(clock) then
      if (slot_reset = '1') then
        -- chipselect
        mes_cs_read_r <= MES_CS_NONE;
      else
        -- chipselect
        mes_cs_read_r <= mes_cs_read_x;
      end if;
    end if;
  end process;

end rtl;
