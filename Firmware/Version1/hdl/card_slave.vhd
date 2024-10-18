----------------------------------------------------------------
-- card_bus_slave - MSX cartridge slave bridge
--
-- Bridge from asynchronous MSX cartridge bus to
-- synchronous Avalon busses for memory and IO
--
-- Note: for now it is assumed the peripheral handles / returns
--       data fast enough, so never wait states are inserted
----------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity card_bus_slave is
  port(
    -- System Clock
    clock             : in std_logic;
    reset             : in std_logic;

    -- MSX-Slot
    slt_reset_n       : in std_logic;
    slt_sltsl_n       : in std_logic;
    slt_iorq_n        : in std_logic;
    slt_rd_n          : in std_logic;
    slt_wr_n          : in std_logic;
    slt_addr          : in std_logic_vector(15 downto 0);
    slt_data          : inout std_logic_vector(7 downto 0);
    slt_bdir_n        : inout std_logic;
    slt_wait_n        : inout std_logic;
    slt_int_n         : in std_logic;
    slt_m1_n          : in std_logic;
    slt_merq_n        : in std_logic;

    -- Synchronous reset output
    slot_reset        : out std_logic;

    -- avalon memory master
    mem_address        : out std_logic_vector(15 downto 0);
    mem_write          : out std_logic;
    mem_writedata      : out std_logic_vector(7 downto 0);
    mem_read           : out std_logic;
    mem_readdata       : in std_logic_vector(8 downto 0);
    mem_readdatavalid  : in std_logic;
    mem_waitrequest    : in std_logic;

    -- avalon io master
    iom_address        : out std_logic_vector(7 downto 0);
    iom_write          : out std_logic;
    iom_writedata      : out std_logic_vector(7 downto 0);
    iom_read           : out std_logic;
    iom_readdata       : in std_logic_vector(8 downto 0);
    iom_readdatavalid  : in std_logic;
    iom_waitrequest    : in std_logic
  );
end card_bus_slave;

architecture rtl of card_bus_slave is

  -- State machine
  type state_t is (S_RESET, S_IDLE, S_MEM_START_READ, S_MEM_RETURN_DATA, S_MEM_START_WRITE, S_MEM_WRITE_DONE,
                   S_IO_START_READ, S_IO_RETURN_DATA, S_IO_START_WRITE, S_IO_WRITE_DONE);
  signal state_x, state_r                 : state_t;

  -- Asynchronous signals
  signal memrd_i, memwr_i                 : std_logic;
  signal iord_i, iowr_i                   : std_logic;

  -- Synchronizers
  signal slt_reset_n_s, slt_reset_n_r     : std_logic;
  signal memrd_s, memrd_r                 : std_logic;
  signal memwr_s, memwr_r                 : std_logic;
  signal iord_s, iord_r                   : std_logic;
  signal iowr_s, iowr_r                   : std_logic;

  -- Synchronous reset output
  signal slot_reset_x, slot_reset_r       : std_logic;
  signal slot_readdata_x, slot_readdata_r : std_logic_vector(8 downto 0);

  -- Avalon memory master
  signal mem_read_x, mem_read_r           : std_logic;
  signal mem_write_x, mem_write_r         : std_logic;
  signal mem_address_x, mem_address_r     : std_logic_vector(15 downto 0);
  signal mem_writedata_x, mem_writedata_r : std_logic_vector(7 downto 0);

  -- Avalon io master
  signal iom_read_x, iom_read_r           : std_logic;
  signal iom_write_x, iom_write_r         : std_logic;
  signal iom_address_x, iom_address_r     : std_logic_vector(7 downto 0);
  signal iom_writedata_x, iom_writedata_r : std_logic_vector(7 downto 0);

begin

  slot_reset <= slot_reset_r;

  slt_wait_n <= 'Z';  -- For now never generate wait states

  -- Asynchronous signals
  memrd_i <= '1' when slt_sltsl_n = '0' and slt_merq_n = '0' and slt_rd_n = '0' else '0';
  memwr_i <= '1' when slt_sltsl_n = '0' and slt_merq_n = '0' and slt_wr_n = '0' else '0';
  iord_i <= '1' when slt_iorq_n = '0' and slt_rd_n = '0' else '0';
  iowr_i <= '1' when slt_iorq_n = '0' and slt_wr_n = '0' else '0';

  -- Synchronizers
  slt_reset_n_s <= slt_reset_n when rising_edge(clock);
  slt_reset_n_r <= slt_reset_n_s when rising_edge(clock);
  memrd_s <= memrd_i when rising_edge(clock);
  memrd_r <= memrd_s when rising_edge(clock);
  memwr_s <= memwr_i when rising_edge(clock);
  memwr_r <= memwr_s when rising_edge(clock);
  iord_s <= iord_i when rising_edge(clock);
  iord_r <= iord_s when rising_edge(clock);
  iowr_s <= iowr_i when rising_edge(clock);
  iowr_r <= iowr_s when rising_edge(clock);

  -- Avalon memory master
  mem_address   <= mem_address_r;
  mem_write     <= mem_write_r;
  mem_writedata <= mem_writedata_r;
  mem_read      <= mem_read_r;

  -- Avalon io master
  iom_address   <= iom_address_r;
  iom_write     <= iom_write_r;
  iom_writedata <= iom_writedata_r;
  iom_read      <= iom_read_r;

  -- Memory state-machine
  mem : process(all)
  begin
    state_x <= state_r;

    slot_reset_x <= '0';
    slot_readdata_x <= slot_readdata_r;

    mem_read_x <= '0';
    mem_write_x <= '0';
    mem_address_x <= mem_address_r;
    mem_writedata_x <= mem_writedata_r;

    iom_read_x <= '0';
    iom_write_x <= '0';
    iom_address_x <= iom_address_r;
    iom_writedata_x <= iom_writedata_r;

    slt_bdir_n <= 'Z';

    if (slot_readdata_r(8) = '1') then
      slt_data <= slot_readdata_r(7 downto 0);
    else
      slt_data <= (others => 'Z');
    end if;

    case (state_r) is
      when S_RESET =>
        slot_reset_x <= '1';
        if (slt_reset_n_r = '1') then
          state_x <= S_IDLE;
        end if;

      when S_IDLE =>
        -- Note that no synchronizers are needed for address
        -- and data from the slot as the signals are guaranteed
        -- to be stable when one of the read/writes gets active
        if (slt_reset_n_r = '0') then
          state_x <= S_RESET;
        elsif (memrd_r = '1') then
          mem_read_x <= '1';
          mem_address_x <= slt_addr;
          state_x <= S_MEM_START_READ;
        elsif (memwr_r = '1') then
          mem_write_x <= '1';
          mem_address_x <= slt_addr;
          mem_writedata_x <= slt_data;
          state_x <= S_MEM_START_WRITE;
        elsif (iord_r = '1') then
          iom_read_x <= '1';
          iom_address_x <= slt_addr(7 downto 0);
          state_x <= S_IO_START_READ;
        elsif (iowr_r = '1') then
          iom_write_x <= '1';
          iom_address_x <= slt_addr(7 downto 0);
          iom_writedata_x <= slt_data;
          state_x <= S_IO_START_WRITE;
        end if;

      when S_MEM_START_READ =>
        -- Read data from peripherals (avalon master interface)
        mem_read_x <= '1';
        if (mem_waitrequest = '0') then
          mem_read_x <= '0';
          state_x <= S_MEM_RETURN_DATA;
        end if;
      when S_MEM_RETURN_DATA =>
        -- Show the data on the Z80 bus
        if (mem_readdatavalid = '1') then
          slot_readdata_x <= mem_readdata;
        end if;
        if (memrd_s = '0') then
          slot_readdata_x(8) <= '0';
          state_x <= S_IDLE;
        end if;

      when S_MEM_START_WRITE =>
        if (mem_waitrequest = '1') then
          -- Another write state
          mem_write_x <= '1';
        else
          -- We're done
          if (memwr_s = '0') then
            state_x <= S_IDLE;
          else
            state_x <= S_MEM_WRITE_DONE;
          end if;
        end if;
      when S_MEM_WRITE_DONE =>
        -- Wait for write signal to deassert
        if (memwr_s = '0') then
          state_x <= S_IDLE;
        end if;

      when S_IO_START_READ =>
        -- Read data from peripherals (avalon master interface)
        iom_read_x <= '1';
        if (iom_waitrequest = '0') then
          iom_read_x <= '0';
          state_x <= S_IO_RETURN_DATA;
        end if;
      when S_IO_RETURN_DATA =>
        -- Show the data on the Z80 bus
        slt_bdir_n <= '0';
        if (iom_readdatavalid = '1') then
          slot_readdata_x <= iom_readdata;
        end if;
        if (iord_s = '0') then
          slot_readdata_x(8) <= '0';
          state_x <= S_IDLE;
        end if;

      when S_IO_START_WRITE =>
        if (iom_waitrequest = '1') then
          -- Another write state
          iom_write_x <= '1';
        else
          -- We're done
          if (iowr_s = '0') then
            state_x <= S_IDLE;
          else
            state_x <= S_IO_WRITE_DONE;
          end if;
        end if;
      when S_IO_WRITE_DONE =>
        -- Wait for write signal to deassert
        if (iowr_s = '0') then
          state_x <= S_IDLE;
        end if;

    end case;
  end process;

  -- Registers
  regs : process(clock, reset)
  begin
    if (reset = '1') then
      state_r <= S_RESET;
      slot_reset_r <= '0';
      slot_readdata_r(8) <= '0';
      mem_read_r <= '0';
      mem_write_r <= '0';
      iom_read_r <= '0';
      iom_write_r <= '0';
    elsif rising_edge(clock) then
      state_r <= state_x;
      slot_reset_r <= slot_reset_x;
      slot_readdata_r(8) <= slot_readdata_x(8);
      mem_read_r <= mem_read_x;
      mem_write_r <= mem_write_x;
      iom_read_r <= iom_read_x;
      iom_write_r <= iom_write_x;
    end if;
    if rising_edge(clock) then
      slot_readdata_r(7 downto 0) <= slot_readdata_x(7 downto 0);
      mem_address_r <= mem_address_x;
      mem_writedata_r <= mem_writedata_x;
      iom_address_r <= iom_address_x;
      iom_writedata_r <= iom_writedata_x;
    end if;
  end process;

end rtl;
