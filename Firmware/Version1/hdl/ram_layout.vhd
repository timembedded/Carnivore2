----------------------------------------------------------------
-- RAM layout
----------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ram_layout is
  port(
    -- clock
    clock                     : IN std_logic;
    slot_reset                : IN std_logic;

    -- RAM memory
    mem_ram_read              : out std_logic;
    mem_ram_write             : out std_logic;
    mem_ram_address           : out std_logic_vector(20 downto 0);
    mem_ram_writedata         : out std_logic_vector(7 downto 0);
    mem_ram_readdata          : in std_logic_vector(7 downto 0);
    mem_ram_readdatavalid     : in std_logic;
    mem_ram_waitrequest       : in std_logic;

    -- Memory mapper
    mes_mapper_read           : in std_logic;
    mes_mapper_write          : in std_logic;
    mes_mapper_address        : in std_logic_vector(19 downto 0);
    mes_mapper_writedata      : in std_logic_vector(7 downto 0);
    mes_mapper_readdata       : out std_logic_vector(7 downto 0);
    mes_mapper_readdatavalid  : out std_logic;
    mes_mapper_waitrequest    : out std_logic
);
end ram_layout;

architecture rtl of ram_layout is

  -- chipselect
  type mes_cs_t is (MES_CS_MAPPER, MES_CS_NONE);
  signal mes_cs_i : mes_cs_t;
  signal mes_cs_read_r, mes_cs_read_x : mes_cs_t;

begin

  --------------------------------------------------------------------
  -- Arbiter
  --------------------------------------------------------------------
  arbiter : process(all)
  begin
    if (mes_mapper_read = '1' or mes_mapper_write = '1') then
      mes_cs_i <= MES_CS_MAPPER;
    else
      mes_cs_i <= MES_CS_NONE;
    end if;
  end process;

  --------------------------------------------------------------------
  -- Read and write
  --------------------------------------------------------------------
  mem_read_write: process(all)
  begin
    mem_ram_read <= '0';
    mem_ram_write <= '0';
    mem_ram_writedata <= (others => '-');
    mem_ram_address <= (others => '-');

    -- Read signal and waitrequest
    mes_mapper_waitrequest <= '1';
    case (mes_cs_i) is
      when MES_CS_MAPPER =>
        mem_ram_read <= mes_mapper_read;
        mem_ram_write <= mes_mapper_write;
        mem_ram_writedata <= mes_mapper_writedata;
        mem_ram_address <= '0' & mes_mapper_address;
        mes_mapper_waitrequest <= mem_ram_waitrequest;
      when others =>
    end case;

    -- Read chipselect state
    if (mes_cs_i /= MES_CS_NONE and mem_ram_waitrequest = '0') then
      mes_cs_read_x <= mes_cs_i;
    elsif (mem_ram_readdatavalid = '1') then
      -- return data, can accept new transfer next clock
      mes_cs_read_x <= MES_CS_NONE;
    else
      -- no active chipselect, keep current state
      mes_cs_read_x <= mes_cs_read_r;
    end if;

    -- Read de-multiplexer
    mes_mapper_readdata <= mem_ram_readdata;
    mes_mapper_readdatavalid <= '0';
    case (mes_cs_read_r) is
      when MES_CS_MAPPER =>
        -- Memory mapper
        mes_mapper_readdatavalid <= mem_ram_readdatavalid;
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
