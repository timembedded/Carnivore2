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
-- IDE
------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ide is
  port(
    -- Clock
    clock       : IN std_logic;
    slot_reset  : IN std_logic;

    -- Avalon slave ports
    mes_ide_read           : in std_logic;
    mes_ide_write          : in std_logic;
    mes_ide_address        : in std_logic_vector(13 downto 0);
    mes_ide_writedata      : in std_logic_vector(7 downto 0);
    mes_ide_readdata       : out std_logic_vector(7 downto 0);
    mes_ide_readdatavalid  : out std_logic;
    mes_ide_waitrequest    : out std_logic;

    -- rom master port
    rom_ide_read           : out std_logic;
    rom_ide_address        : out std_logic_vector(16 downto 0);
    rom_ide_readdata       : in std_logic_vector(7 downto 0);
    rom_ide_readdatavalid  : in std_logic;
    rom_ide_waitrequest    : in std_logic;

    -- CF card interface
    pIDEAdr     : OUT std_logic_vector(2 downto 0);
    pIDEDat     : INOUT std_logic_vector(15 downto 0);
    pIDECS1_n   : OUT std_logic;  -- IDE registers 0x7E00 - 0x7E0F, and data
    pIDECS3_n   : OUT std_logic;  -- IDE registers 0x7E10 - 0x7E1F
    pIDERD_n    : OUT std_logic;
    pIDEWR_n    : OUT std_logic;
    pPIN180     : OUT std_logic;
    pIDE_Rst_n  : OUT std_logic
);
end ide;

architecture rtl of ide is

  type state_t is (S_RESET, S_IDLE, S_READ_REG, S_WRITE_REG);
  signal state_r, state_x : state_t;

  type read_state_t is (RS_IDLE, RS_IDE, RS_ROM);
  signal read_state_x, read_state_r : read_state_t;
  signal read_waitrequest_i : std_logic;

  signal mes_ide_readdatavalid_r, mes_ide_readdatavalid_x : std_logic;
  signal mes_ide_readdata_r, mes_ide_readdata_x           : std_logic_vector(7 downto 0);

  constant IDE_CYCLE_TIME : integer := 15; -- 150ns
  signal ide_delay_count_x, ide_delay_count_r : integer range 0 to IDE_CYCLE_TIME;

  signal ide_port_addr_r, ide_port_addr_x : std_logic_vector(2 downto 0);
  signal ide_port_data_r, ide_port_data_x : std_logic_vector(15 downto 0);
  signal ide_port_cs1_x, ide_port_cs1_r   : std_logic;
  signal ide_port_cs3_x, ide_port_cs3_r   : std_logic;
  signal ide_port_rd_x, ide_port_rd_r     : std_logic;
  signal ide_port_wr_x, ide_port_wr_r     : std_logic;
  signal ide_port_oe_x, ide_port_oe_r     : std_logic;
  signal ide_port_readdata_x, ide_port_readdata_r : std_logic_vector(15 downto 0);
  signal ide_port_readdatavalid_x, ide_port_readdatavalid_r : std_logic;
  signal ide_port_waitrequest_i           : std_logic;

  signal ide_reset_i      : std_logic;
  signal ide_read_reg_i   : std_logic;
  signal ide_read_addr_i  : std_logic_vector(3 downto 0);
  signal ide_write_reg_i  : std_logic;
  signal ide_write_addr_i : std_logic_vector(3 downto 0);
  signal ide_data_i       : std_logic_vector(15 downto 0);

  signal ide_readdata_latch_x, ide_readdata_latch_r : std_logic_vector(7 downto 0);
  signal ide_writedata_latch_x, ide_writedata_latch_r : std_logic_vector(7 downto 0);
  
  signal ide_enable_x, ide_enable_r       : std_logic;
  signal ide_rom_page_x, ide_rom_page_r   : std_logic_vector(2 downto 0);

begin

  pIDEAdr     <= ide_port_addr_r;
  pIDEDat     <= ide_port_data_r when ide_port_oe_r = '1' else (others => 'Z');
  pIDECS1_n   <= not ide_port_cs1_r;
  pIDECS3_n   <= not ide_port_cs3_r;
  pIDERD_n    <= not ide_port_rd_r;
  pIDEWR_n    <= not ide_port_wr_r;
  pPIN180     <= '1';
  pIDE_Rst_n  <= not ide_reset_i;

  --  0x4104            IDE config register
  --                      bit 0    : '0' = disable IDE registers, '1' = enable IDE registers
  --                      bit 7..5 : Flash page number (5 = address MSB, 7 = address LSB !!!)
  --  0x7C00 - 0x7DFF   IDE 16-bit data register
  --  0x7E00 - 0x7E0F   IDE registers
  --  0x7E10 - 0x7EFF   15 x mirror of IDE registers, should not be used

  --------------------------------------------------------
  -- Register write
  --------------------------------------------------------

  process(all)
  begin
    ide_write_addr_i <= "----";
    ide_write_reg_i <= '0';
    ide_writedata_latch_x <= ide_writedata_latch_r;
    ide_data_i <= (others => '-');
    ide_enable_x <= ide_enable_r;
    ide_rom_page_x <= ide_rom_page_r;

    if (mes_ide_write = '1') then
      if (mes_ide_address = "00"&x"104") then
        -- 0x4104            IDE config register
        ide_enable_x <= mes_ide_writedata(0);
        ide_rom_page_x <= mes_ide_writedata(5) & mes_ide_writedata(6) & mes_ide_writedata(7);
      elsif (mes_ide_address(13 downto 9) = "11"&"110" and ide_enable_r = '1') then
        -- 0x7C00 - 0x7DFF   IDE 16-bit data register
        if (mes_ide_address(0) = '0') then
          ide_writedata_latch_x <= mes_ide_writedata;
        else
          ide_write_addr_i <= "0000";
          ide_data_i <= mes_ide_writedata & ide_writedata_latch_r;
          ide_write_reg_i <= '1';
        end if;
      elsif (mes_ide_address(13 downto 8) = "11"&"1110" and ide_enable_r = '1') then
        -- 0x7E00 - 0x7E0F   IDE registers
        ide_write_addr_i <= mes_ide_address(3 downto 0);
        ide_data_i <= mes_ide_writedata & mes_ide_writedata;
        ide_write_reg_i <= '1';
      end if;
    end if;
  end process;

  --------------------------------------------------------
  -- Register/ROM read
  --------------------------------------------------------

  rom_ide_address <= ide_rom_page_r & mes_ide_address;

  mes_ide_waitrequest <= read_waitrequest_i or ide_port_waitrequest_i;

  process(all)
  begin
    read_state_x <= read_state_r;
    read_waitrequest_i <= '1';

    mes_ide_readdatavalid_x <= '0';
    mes_ide_readdata_x <= (others => '0');

    ide_readdata_latch_x <= ide_readdata_latch_r;
    ide_read_reg_i <= '0';
    ide_read_addr_i <= "----";

    rom_ide_read <= '0';

    case (read_state_r) is
      when RS_IDLE =>
        -- Accept transfers in this state
        read_waitrequest_i <= '0';

        mes_ide_readdatavalid <= mes_ide_readdatavalid_r;
        mes_ide_readdata <= mes_ide_readdata_r;

        -- Address decode
        if (mes_ide_read = '1' and mes_ide_address(13 downto 9) = "11"&"110" and ide_enable_r = '1') then
          -- 0x7C00 - 0x7DFF   IDE 16-bit data register
          if (mes_ide_address(0) = '0') then
            ide_read_reg_i <= '1';
            ide_read_addr_i <= "0000";
            read_state_x <= RS_IDE;
          else
            -- the latched high-byte
            mes_ide_readdata_x <= ide_readdata_latch_r;
            mes_ide_readdatavalid_x <= '1';
          end if;
        elsif (mes_ide_read = '1' and mes_ide_address(13 downto 8) = "11"&"1110" and ide_enable_r = '1') then
          -- 0x7E00 - 0x7E0F   IDE registers
          ide_read_reg_i <= '1';
          ide_read_addr_i <= mes_ide_address(3 downto 0);
          read_state_x <= RS_IDE;
        elsif (mes_ide_read = '1') then
          -- ROM
          rom_ide_read <= '1';
          if (rom_ide_waitrequest = '1') then
            read_waitrequest_i <= '1';
          else
            read_state_x <= RS_ROM;
          end if;
        end if;

      when RS_IDE =>
        -- Read IDE register
        ide_readdata_latch_x <= ide_port_readdata_r(15 downto 8);
        mes_ide_readdata <= ide_port_readdata_r(7 downto 0);
        mes_ide_readdatavalid <= ide_port_readdatavalid_r;
        if (ide_port_readdatavalid_r = '1') then
          read_state_x <= RS_IDLE;
        end if;

      when RS_ROM =>
        -- Read from flash, wait for datavalid
        mes_ide_readdata <= rom_ide_readdata;
        mes_ide_readdatavalid <= rom_ide_readdatavalid;
        if (rom_ide_readdatavalid = '1') then
          read_state_x <= RS_IDLE;
        end if;
    end case;
  end process;

  ----------------------------------------------------------------
  -- IDE state machine
  ----------------------------------------------------------------

  process(all)
  begin
    state_x <= state_r;
    ide_reset_i <= '0';
    ide_delay_count_x <= ide_delay_count_r;
    ide_port_rd_x <= '0';
    ide_port_wr_x <= '0';
    ide_port_oe_x <= '0';
    ide_port_cs1_x <= ide_port_cs1_r;
    ide_port_cs3_x <= ide_port_cs3_r;
    ide_port_addr_x <= ide_port_addr_r;
    ide_port_data_x <= ide_port_data_r;
    ide_port_readdata_x <= ide_port_readdata_r;
    ide_port_readdatavalid_x <= '0';
    ide_port_waitrequest_i <= '1';

    case (state_r) is
      when S_RESET =>
        ide_reset_i <= '1';
        ide_port_cs1_x <= '0';
        ide_port_cs3_x <= '0';
        if (ide_delay_count_r < IDE_CYCLE_TIME) then
          ide_delay_count_x <= ide_delay_count_r + 1;
        else
          state_x <= S_IDLE;
        end if;

      when S_IDLE =>
        -- Cycle timing
        ide_delay_count_x <= 0;

        -- Accept transfers only in this state
        ide_port_waitrequest_i <= '0';

        -- IDE register read/write
        ide_port_cs1_x <= '0';
        ide_port_cs3_x <= '0';
        if (ide_read_reg_i = '1') then
          if (ide_read_addr_i(3) = '0') then
            ide_port_cs1_x <= '1';
          else
            ide_port_cs3_x <= '1';
          end if;
          ide_port_addr_x <= ide_read_addr_i(2 downto 0);
          state_x <= S_READ_REG;
        elsif (ide_write_reg_i = '1') then
          if (ide_write_addr_i(3) = '0') then
            ide_port_cs1_x <= '1';
          else
            ide_port_cs3_x <= '1';
          end if;
          ide_port_addr_x <= ide_write_addr_i(2 downto 0);
          ide_port_oe_x <= '1';
          ide_port_data_x <= ide_data_i;
          state_x <= S_WRITE_REG;
        end if;

      when S_READ_REG =>
        if (ide_delay_count_r < IDE_CYCLE_TIME) then
          ide_port_rd_x <= '1';
          ide_delay_count_x <= ide_delay_count_r + 1;
        else
          ide_port_rd_x <= '0';
          ide_port_readdata_x <= pIDEDat;
          ide_port_readdatavalid_x <= '1';
          state_x <= S_IDLE;
        end if;

      when S_WRITE_REG =>
        ide_port_oe_x <= '1';
        if (ide_delay_count_r < IDE_CYCLE_TIME) then
          ide_port_wr_x <= '1';
          ide_delay_count_x <= ide_delay_count_r + 1;
        else
          ide_port_wr_x <= '0';
          state_x <= S_IDLE;
        end if;
    end case;

  end process;

  ----------------------------------------------------------------
  -- Registers
  ----------------------------------------------------------------
  process(clock)
  begin
    if rising_edge(clock) then
      if (slot_reset = '1') then
        state_r <= S_RESET;
        read_state_r <= RS_IDLE;
        ide_delay_count_r <= 0;

        mes_ide_readdatavalid_r <= '0';

        ide_port_cs1_r <= '0';
        ide_port_cs3_r <= '0';
        ide_port_rd_r <= '0';
        ide_port_wr_r <= '0';
        ide_port_oe_r <= '0';
        ide_port_readdatavalid_r <= '0';

        ide_enable_r <= '0' ;
        ide_rom_page_r <= "000";
      else
        state_r <= state_x;
        read_state_r <= read_state_x;
        ide_delay_count_r <= ide_delay_count_x;

        mes_ide_readdatavalid_r <= mes_ide_readdatavalid_x;

        ide_port_cs1_r <= ide_port_cs1_x;
        ide_port_cs3_r <= ide_port_cs3_x;
        ide_port_rd_r <= ide_port_rd_x;
        ide_port_wr_r <= ide_port_wr_x;
        ide_port_oe_r <= ide_port_oe_x;
        ide_port_readdatavalid_r <= ide_port_readdatavalid_x;

        ide_enable_r <= ide_enable_x;
        ide_rom_page_r <= ide_rom_page_x;
      end if;

      mes_ide_readdata_r <= mes_ide_readdata_x;

      ide_port_addr_r <= ide_port_addr_x;
      ide_port_data_r <= ide_port_data_x;
      ide_port_readdata_r <= ide_port_readdata_x;

      ide_readdata_latch_r <= ide_readdata_latch_x;
      ide_writedata_latch_r <= ide_writedata_latch_x;
    end if;
  end process;

end rtl;
