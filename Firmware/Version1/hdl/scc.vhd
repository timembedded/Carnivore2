----------------------------------------------------------------
-- SCC
----------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity scc is
  port(
    -- Clock
    clock       : IN std_logic;
    reset       : IN std_logic
  );
end top;

architecture RTL of top is

  -- Sltsel
  signal pSltSltslt_n	: std_logic;
  signal sltt	: std_logic;

  signal DevHit      : std_logic;

  -- SCC
  signal SccEna :std_logic;

  signal Dec1FFE     : std_logic;
  signal DecSccA     : std_logic;
  signal DecSccB     : std_logic;

  signal SccBank2    : std_logic_vector(7 downto 0);
  signal SccBank3    : std_logic_vector(7 downto 0);
  signal SccModeA    : std_logic_vector(7 downto 0);
  signal SccModeB    : std_logic_vector(7 downto 0);

  signal SccRegWe    : std_logic;
  signal SccModWe    : std_logic;
  signal SccWavCe    : std_logic;
  signal SccWavOe    : std_logic;
  signal SccWavWe    : std_logic;
  signal SccWavWx    : std_logic;
  signal SccWavAdr   : std_logic_vector(4 downto 0);
  signal SccWavDat   : std_logic_vector(7 downto 0);

begin

  ----------------------------------------------------------------
  -- Decode Cartrige
  ----------------------------------------------------------------

  Dec1FFE <= '1' when pSltAdr(12 downto 1) = "111111111111" 
                 else '0';
  DecSccA <= '1' when pSltAdr(15 downto 11) = "10011" and SccModeB(5) = '0' and SccBank2(5 downto 0) = "111111"
                 else '0';
  DecSccB <= '1' when pSltAdr(15 downto 11) = "10111" and SccModeB(5) = '1' and SccBank3(7) = '1'
                 else '0';
  
  ----------------------------------------------------------------
  -- Conf register 
  ----------------------------------------------------------------

  SccEna <= '0';

  ----------------------------------------------------------------
  -- Slot access control
  ----------------------------------------------------------------
  process(pSltClk_n, pSltRst_n, pSltIorq_n, pSltMerq_n, pSltRd_n, pSltWr_n)

    variable DevAcs0 : std_logic;
    variable DevAcs1 : std_logic;

  begin

--    if ((pSltIorq_n = '0' or pSltSltsl_n = '0') and (pSltRd_n = '0' or pSltWr_n = '0')) then
    if ((pSltIorq_n = '0' or pSltMerq_n = '0') and (pSltRd_n = '0' or pSltWr_n = '0')) then
      DevAcs0 := '1';
    else
      DevAcs0 := '0';
    end if;

    if (DevAcs0 = '1' and DevAcs1 = '0') then
      DevHit <= '1';
    else
      DevHit <= '0';
    end if;

    if (pSltRst_n = '0') then
      DevAcs1 := '0';
    elsif (pSltClk_n'event and pSltClk_n = '1') then
      DevAcs1 := DevAcs0;
    end if;

  end process;

  ----------------------------------------------------------------
  -- SCC register / wave memory access
  ----------------------------------------------------------------
  process(pSltClk_n, pSltRst_n)

  begin

    if (pSltRst_n = '0') then

      SccBank2   <= "00000010";
      SccBank3   <= "00000011";
      SccModeA   <= (others => '0');
      SccModeB   <= (others => '0');

      SccWavWx   <= '0';
      SccWavAdr  <= (others => '0');
      SccWavDat  <= (others => '0');

    elsif (pSltClk_n'event and pSltClk_n = '1') then

      -- Mapped I/O port access on 9000-97FFh ... Bank resister write
      if (SccEna = '1' and pSltWr_n = '0' and pSltAdr(15 downto 11) = "10010" and
          SccModeB(4) = '0') then
        SccBank2 <= pSltDat;
      end if;
      -- Mapped I/O port access on B000-B7FFh ... Bank resister write
      if (SccEna = '1' and pSltWr_n = '0' and pSltAdr(15 downto 11) = "10110" and
          SccModeA(6) = '0' and SccModeA(4) = '0' and SccModeB(4) = '0') then
        SccBank3 <= pSltDat;
      end if;

      -- Mapped I/O port access on 7FFE-7FFFh ... Resister write
      if (SccEna = '1' and pSltWr_n = '0' and pSltAdr(15 downto 13) = "011" and Dec1FFE = '1' and
          SccModeB(5 downto 4) = "00") then
        SccModeA <= pSltDat;
      end if;

      -- Mapped I/O port access on BFFE-BFFFh ... Resister write
      if (SccEna = '1' and pSltWr_n = '0' and pSltAdr(15 downto 13) = "101" and Dec1FFE = '1' and
          SccModeA(6) = '0' and SccModeA(4) = '0') then
        SccModeB <= pSltDat;
      end if;

      -- Mapped I/O port access on 9860-987Fh ... Wave memory copy
      if (SccEna = '1' and pSltWr_n = '0' and pSltAdr(7 downto 5) = "011" and
          DevHit = '1' and SccModeB(4) = '0' and DecSccA = '1') then
        SccWavAdr <= pSltAdr(4 downto 0);
        SccWavDat <= pSltDat;
        SccWavWx  <= '1';
      else
        SccWavWx  <= '0';
      end if;

    end if;

  end process;

  -- Mapped I/O port access on 9800-987Fh / B800-B89Fh ... Wave memory
  SccWavCe <= '1' when SccEna = '1' and DevHit = '1' and SccModeB(4) = '0' and
                       (DecSccA = '1' or DecSccB = '1')
                  else '0';

  -- Mapped I/O port access on 9800-987Fh / B800-B89Fh ... Wave memory
  SccWavOe <= '1' when SccEna = '1' and pSltRd_n = '0' and SccModeB(4) = '0' and
                       ((DecSccA = '1' and pSltAdr(7) = '0') or
                        (DecSccB = '1' and (pSltAdr(7) = '0' or pSltAdr(6 downto 5) = "00")))
                  else '0';

  -- Mapped I/O port access on 9800-987Fh / B800-B89Fh ... Wave memory
  SccWavWe <= '1' when SccEna = '1' and pSltWr_n = '0' and DevHit = '1' and SccModeB(4) = '0' and
                       ((DecSccA = '1' and pSltAdr(7) = '0') or DecSccB = '1')
                  else '0';

  -- Mapped I/O port access on 9880-988Fh / B8A0-B8AF ... Resister write
  SccRegWe <= '1' when SccEna = '1' and pSltWr_n = '0' and
                       ((DecSccA = '1' and pSltAdr(7 downto 5) = "100") or
                        (DecSccB = '1' and pSltAdr(7 downto 5) = "101")) and
                       DevHit = '1' and SccModeB(4) = '0'
                  else '0';

  -- Mapped I/O port access on 98C0-98FFh / B8C0-B8DFh ... Resister write
  SccModWe <= '1' when SccEna = '1' and pSltWr_n = '0' and pSltAdr(7 downto 6) = "11" and
                       (DecSccA = '1' or (pSltAdr(5) = '0' and DecSccB = '1')) and
                       DevHit = '1' and SccModeB(4) = '0'
                  else '0';

end RTL;

  