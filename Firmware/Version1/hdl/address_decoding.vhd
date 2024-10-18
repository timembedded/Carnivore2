----------------------------------------------------------------
-- MSX slot address decoding
----------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity address_decoding is
  port(
    -- clock
    clock       : IN std_logic;
    slot_reset  : IN std_logic;

    -- Avalon memory slave
    mes_read           : IN std_logic;
    mes_write          : IN std_logic;
    mes_address        : IN std_logic_vector(15 downto 0);
    mes_writedata      : IN std_logic_vector(7 downto 0);
    mes_readdata       : OUT std_logic_vector(8 downto 0);
    mes_readdatavalid  : OUT std_logic;
    mes_waitrequest    : OUT std_logic;

    -- Avalon io slave
    ios_read           : IN std_logic;
    ios_write          : IN std_logic;
    ios_address        : IN std_logic_vector(7 downto 0);
    ios_writedata      : IN std_logic_vector(7 downto 0);
    ios_readdata       : OUT std_logic_vector(8 downto 0);
    ios_readdatavalid  : OUT std_logic;
    ios_waitrequest    : OUT std_logic;

    -- Functions
    test_reg           : OUT std_logic_vector(7 downto 0);

    -- Subslot 1 - FM-Pack
    mem_fmpac_read           : OUT std_logic;
    mem_fmpac_write          : OUT std_logic;
    mem_fmpac_address        : OUT std_logic_vector(13 downto 0);
    mem_fmpac_writedata      : OUT std_logic_vector(7 downto 0);
    mem_fmpac_readdata       : IN std_logic_vector(7 downto 0);
    mem_fmpac_readdatavalid  : IN std_logic;
    mem_fmpac_waitrequest    : IN std_logic;
    iom_fmpac_write          : OUT std_logic;
    iom_fmpac_address        : OUT std_logic_vector(0 downto 0);
    iom_fmpac_writedata      : OUT std_logic_vector(7 downto 0);
    iom_fmpac_waitrequest    : IN std_logic
);
end address_decoding;

architecture rtl of address_decoding is

  -- Slot expander
  signal slot_expand_reg_x, slot_expand_reg_r   : std_logic_vector(7 downto 0);
  signal test_reg_x, test_reg_r                 : std_logic_vector(7 downto 0);
  signal exp_select_i                           : std_logic_vector(3 downto 0);

  -- Chip select
  type mem_cs_t is (MEM_CS_NONE, MEM_CS_EXTREG, MEM_CS_FMPAC, MEM_CS_TESTREG);
  type iom_cs_t is (IOM_CS_NONE, IOM_CS_FMPAC, IOM_CS_TESTREG);
  signal mem_cs_i, mem_cs_read_x, mem_cs_read_r : mem_cs_t;
  signal iom_cs_i, iom_cs_read_x, iom_cs_read_r : iom_cs_t;

  -- Reads/writes
  signal mem_fmpac_read_i                         : std_logic;
  signal mem_fmpac_write_i                        : std_logic;
  signal iom_fmpac_write_i                        : std_logic;

   -- Avalon memory slave
  signal mes_read_ff                              : std_logic;
  signal mes_readdata_x, mes_readdata_r           : std_logic_vector(8 downto 0);
  signal mes_readdatavalid_x, mes_readdatavalid_r : std_logic;
  signal mes_read_waitrequest_x, mes_read_waitrequest_r : std_logic;

    -- Avalon io slave
  signal ios_read_ff                              : std_logic;
  signal ios_readdata_x, ios_readdata_r           : std_logic_vector(8 downto 0);
  signal ios_readdatavalid_x, ios_readdatavalid_r : std_logic;
  signal ios_read_waitrequest_x, ios_read_waitrequest_r : std_logic;

begin

  test_reg <= test_reg_r;

  -- Data out to slave ports
  mes_readdata <= mes_readdata_r;
  mes_readdatavalid <= mes_readdatavalid_r;
  ios_readdata <= ios_readdata_r;
  ios_readdatavalid <= ios_readdatavalid_r;

  -- FM-Pac
  mem_fmpac_read  <= mem_fmpac_read_i;
  mem_fmpac_write <= mem_fmpac_write_i;
  iom_fmpac_write <= iom_fmpac_write_i;
  mem_fmpac_address        <= mes_address(13 downto 0);
  mem_fmpac_writedata      <= mes_writedata;
  iom_fmpac_address        <= ios_address(0 downto 0);
  iom_fmpac_writedata      <= ios_writedata;


  --------------------------------------------------------------------
  -- Test register
  --------------------------------------------------------------------

  test_reg_x <= ios_writedata when ios_write = '1' and ios_address = x"52" else
                test_reg_r;


  --------------------------------------------------------------------
  -- Slot expander
  --------------------------------------------------------------------

  slot_expand_reg_x <= mes_writedata when mes_write = '1' and mes_address = x"ffff" else
                       slot_expand_reg_r;

  exp_select_i(0) <= '1' when (mes_address(15 downto 14) = "00" and slot_expand_reg_r(1 downto 0) = "00") else
                     '1' when (mes_address(15 downto 14) = "01" and slot_expand_reg_r(3 downto 2) = "00") else
                     '1' when (mes_address(15 downto 14) = "10" and slot_expand_reg_r(5 downto 4) = "00") else
                     '1' when (mes_address(15 downto 14) = "11" and slot_expand_reg_r(7 downto 6) = "00") else '0';

  exp_select_i(1) <= '1' when (mes_address(15 downto 14) = "00" and slot_expand_reg_r(1 downto 0) = "01") else
                     '1' when (mes_address(15 downto 14) = "01" and slot_expand_reg_r(3 downto 2) = "01") else
                     '1' when (mes_address(15 downto 14) = "10" and slot_expand_reg_r(5 downto 4) = "01") else
                     '1' when (mes_address(15 downto 14) = "11" and slot_expand_reg_r(7 downto 6) = "01") else '0';

  exp_select_i(2) <= '1' when (mes_address(15 downto 14) = "00" and slot_expand_reg_r(1 downto 0) = "10") else
                     '1' when (mes_address(15 downto 14) = "01" and slot_expand_reg_r(3 downto 2) = "10") else
                     '1' when (mes_address(15 downto 14) = "10" and slot_expand_reg_r(5 downto 4) = "10") else
                     '1' when (mes_address(15 downto 14) = "11" and slot_expand_reg_r(7 downto 6) = "10") else '0';

  exp_select_i(3) <= '1' when (mes_address(15 downto 14) = "00" and slot_expand_reg_r(1 downto 0) = "11") else
                     '1' when (mes_address(15 downto 14) = "01" and slot_expand_reg_r(3 downto 2) = "11") else
                     '1' when (mes_address(15 downto 14) = "10" and slot_expand_reg_r(5 downto 4) = "11") else
                     '1' when (mes_address(15 downto 14) = "11" and slot_expand_reg_r(7 downto 6) = "11") else '0';


  --------------------------------------------------------------------
  -- Memory chipselects
  --------------------------------------------------------------------

  -- Address decoding
  mem_chipselect : process(all)
  begin
    if (mes_address = x"ffff") then
      mem_cs_i <= MEM_CS_EXTREG;
    elsif (exp_select_i(1) = '1' and mes_address(15 downto 14) = "01") then
      mem_cs_i <= MEM_CS_FMPAC;
    elsif (exp_select_i(0) = '1' and mes_address = x"8000") then
      mem_cs_i <= MEM_CS_TESTREG;
    else
      mem_cs_i <= MEM_CS_NONE;
    end if;
  end process;

  -- Read
  mem_chipselect_read : process(all)
  begin
    -- read signals
    mem_fmpac_read_i <= '0';

    -- default for any active chipselect
    mes_read_waitrequest_x <= '1';
    mem_cs_read_x <= mem_cs_i;

    -- create read signals
    if (mes_read = '1' and mem_cs_i = MEM_CS_EXTREG) then
      -- internal register
    elsif (mes_read = '1' and mem_cs_i = MEM_CS_FMPAC) then
      -- FM-Pack
      mem_fmpac_read_i <= '1';
    elsif (mes_read = '1' and mem_cs_i = MEM_CS_TESTREG) then
      -- internal register
    elsif (mes_readdatavalid_r = '1') then
      -- return data, can accept new transfer next clock
      mem_cs_read_x <= MEM_CS_NONE;
      mes_read_waitrequest_x <= '0';
    else
      -- no active chipselect, keep current state
      mem_cs_read_x <= mem_cs_read_r;
      mes_read_waitrequest_x <= mes_read_waitrequest_r;
    end if;
  end process;

  -- Write
  mem_chipselect_write : process(all)
  begin
    -- write signals
    mem_fmpac_write_i <= '0';

    -- create write signals
    if (mes_write = '1' and mem_cs_i = MEM_CS_FMPAC) then
      -- FM-Pack
      mem_fmpac_write_i <= '1';
    end if;
  end process;


  --------------------------------------------------------------------
  -- I/O chipselects
  --------------------------------------------------------------------

  -- Address decoding
  iom_chipselect : process(all)
  begin
    if (ios_address(7 downto 1) = "0111110") then
      iom_cs_i <= IOM_CS_FMPAC;
    elsif (ios_address = x"52") then
      iom_cs_i <= IOM_CS_TESTREG;
    else
      iom_cs_i <= IOM_CS_NONE;
    end if;
  end process;

  -- Read
  iom_chipselect_read : process(all)
  begin
    -- read signals
    -- ...

    -- default for any active chipselect
    ios_read_waitrequest_x <= '1';
    iom_cs_read_x <= iom_cs_i;

    -- create read signals
    if (iom_cs_i = IOM_CS_TESTREG) then
      -- internal register
    elsif (ios_readdatavalid_r = '1') then
      -- return data, can accept new transfer next clock
      iom_cs_read_x <= IOM_CS_NONE;
      ios_read_waitrequest_x <= '0';
    else
      -- keep current state
      iom_cs_read_x <= iom_cs_read_r;
      ios_read_waitrequest_x <= ios_read_waitrequest_r;
    end if;
  end process;

  -- Write
  iom_chipselect_write : process(all)
  begin
    -- write signals
    iom_fmpac_write_i <= '0';

    -- create write signals
    if (ios_write = '1' and ios_address(7 downto 1) = "0111110") then
      -- 7C..7D
      iom_fmpac_write_i <= '1';
    end if;
  end process;


  --------------------------------------------------------------------
  -- Data output mux
  --------------------------------------------------------------------

  mes_read_ff <= mes_read when rising_edge(clock);
  ios_read_ff <= ios_read when rising_edge(clock);

  out_mux : process(all)
  begin
    -- Defaults
    mes_readdata_x <= "0--------";
    mes_readdatavalid_x <= '0';
    ios_readdata_x <= "0--------";
    ios_readdatavalid_x <= '0';

    -- Memory waitrequest
    case (mem_cs_i) is
      when MEM_CS_FMPAC =>
        mes_waitrequest <= mem_fmpac_waitrequest;
      when others =>
        mes_waitrequest <= mes_read_waitrequest_r;
    end case;

    -- Memory data
    case (mem_cs_read_r) is
      when MEM_CS_EXTREG =>
        -- ALL SLOTS -> Slot expander
        if (mes_read_ff = '1') then
          mes_readdatavalid_x <= '1';
          mes_readdata_x <= '1' & (not slot_expand_reg_r);
        end if;
      when MEM_CS_TESTREG => 
        -- SUBSLOT 0 -> Test register @0x8000
        if (mes_read_ff = '1') then
          mes_readdatavalid_x <= '1';
          mes_readdata_x <= '1' & test_reg_r;
        end if;
      when MEM_CS_FMPAC =>
        -- FM-Pac
        if (mem_fmpac_readdatavalid = '1') then
          mes_readdatavalid_x <= '1';
          mes_readdata_x <= '1' & mem_fmpac_readdata;
        end if;
      when others =>
        mes_readdatavalid_x <= mes_read_ff;
    end case;

    -- I/O waitrequest
   case (iom_cs_i) is
      when IOM_CS_FMPAC =>
        ios_waitrequest <= iom_fmpac_waitrequest;
      when others =>
        ios_waitrequest <= ios_read_waitrequest_r;
    end case;

   -- I/O data
   case (iom_cs_read_r) is
      when IOM_CS_TESTREG =>
        -- Test register
        if (mes_read_ff = '1') then
          ios_readdata_x <= '1' & test_reg_r;
          ios_readdatavalid_x <= '1';
        end if;
      when others =>
        ios_readdatavalid_x <= ios_read_ff;
    end case;

  end process;


  --------------------------------------------------------------------
  -- Registers
  --------------------------------------------------------------------
  process(clock)
  begin
    if rising_edge(clock) then
      if slot_reset = '1' then
        slot_expand_reg_r <= x"00";
        test_reg_r <= x"A1";
        mem_cs_read_r <= MEM_CS_NONE;
        iom_cs_read_r <= IOM_CS_NONE;
      else
        -- internal registers
        slot_expand_reg_r <= slot_expand_reg_x;
        test_reg_r <= test_reg_x;
        -- chipselects
        mem_cs_read_r <= mem_cs_read_x;
        iom_cs_read_r <= iom_cs_read_x;
        -- Avalon memory slave
        mes_readdata_r <= mes_readdata_x;
        mes_readdatavalid_r <= mes_readdatavalid_x;
        mes_read_waitrequest_r <= mes_read_waitrequest_x;
        -- Avalon io slave
        ios_readdata_r <= ios_readdata_x;
        ios_readdatavalid_r <= ios_readdatavalid_x;
        ios_read_waitrequest_r <= ios_read_waitrequest_x;
      end if;
    end if;
  end process;

end rtl;
