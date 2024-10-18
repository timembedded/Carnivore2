----------------------------------------------------------------
-- IDE
----------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top is
  port(
    -- Clock
    clock       : IN std_logic;
    reset       : IN std_logic;

    -- CF card interface
    pIDEAdr     : OUT std_logic_vector(2 downto 0);
    pIDEDat     : INOUT std_logic_vector(15 downto 0);
    pIDECS1_n   : OUT std_logic;
    pIDECS3_n   : OUT std_logic;
    pIDERD_n    : OUT std_logic;
    pIDEWR_n    : OUT std_logic;
    pPIN180     : OUT std_logic;
    pIDE_Rst_n  : OUT std_logic
);
end top;

architecture RTL of top is

  -- IDE CF adapter
  signal CLC_n         : std_logic;  
  signal IDEROMCs_n    : std_logic;
  signal IDEROMADDR    : std_logic_vector(16 downto 0);
  signal DecIDEconf    : std_logic;  
  signal cReg          : std_logic_vector(7 downto 0);  
  signal IDEReg        : std_logic;

begin

  ----------------------------------------------------------------
  -- Set IDE Register
  ----------------------------------------------------------------
  DecIDEconf <= '1' when Sltsl_D_n = '0' and pSltAdr(15 downto 0) = "0100000100000100" 
                   else '0';
  process(pSltRst_n, pSltClk_n)
  begin
    if (pSltRst_n = '0') then
      cReg  <= "00000000";
    elsif (Wr_n'event and Wr_n = '0') then
      if (DecIDEconf = '1') then
        cReg <= pSltDat;
      end if;
    end if;
  end process;

  ----------------------------------------------------------------
  -- IDE Processing
  ---------------------------------------------------------------- 
  IDEReg    <= '0' when pSltAdr(9 downto 8) = "11" 
             else '1' when Sltsl_D_n = '0' and cReg(0) = '1' and pSltAdr(15 downto 10) = "011111" -- 7C00h-7FEFh
             else '0';

  process(all)
  begin
   if pSltClk'event and pSltClk = '1' then
      if(IDEReg = '1' and pSltAdr(9) = '0' and  pSltAdr(0) = '0' and Rd_n = '0') then
        IDEsIN <=  pIDEDat(15 downto 8);  
      end if;
   end if;
  end process;

  process(all)
  begin
    if (IDEReg = '1' and pSltAdr(9) = '0' and pSltWr_n = '0' and pSltAdr(0) = '0') then 
      IDEsOUT <=  pSltDat;  
    end if;   
  end process; 

  pIDEDat(15 downto 8)  <=  pSltDat when IDEReg = '1' and pSltAdr(9) = '1' and Rd_n = '1' and Rd_n1 = '1' and pSltRd_n = '1'
                       else pSltDat when IDEReg = '1' and Rd_n = '1' and Rd_n1 = '1' and pSltRd_n = '1'
             else (others => 'Z');

  pIDEDat(7 downto 0)   <=  pSltDat when IDEReg = '1' and pSltAdr(9) = '1' and Rd_n = '1' and Rd_n1 = '1' and pSltRd_n = '1'
             else IDEsOUT when IDEReg = '1' and pSltAdr(9) = '0' and pSltAdr(0) = '1' 
                           and Rd_n = '1' and Rd_n1 = '1' and pSltRd_n = '1'
             else (others => 'Z');

  pIDEAdr   <= pSltAdr(2 downto 0) when pSltAdr(9) = '1'
                   else "000";

  pIDECS1_n             <= pSltAdr(3) when pSltAdr(9) = '1' 
                                   else '0';

  pIDECS3_n             <= not pSltAdr(3) when pSltAdr(9) = '1'
                                   else '1';

  pIDERD_n    <= Rdh_n;
  pIDEWR_n    <= Wrh_n;
  pPIN180   <= '1';
  pIDE_Rst_n  <= pSltRst_n;

  Rdh_n     <= '0' when Rd_n = '0' and IDEReg = '1' and (pSltAdr(9) = '1' or pSltAdr(0) = '0') else '1';
  Wrh_n     <= '0' when Wr_n = '0' and IDEReg = '1' and (pSltAdr(9) = '1' or pSltAdr(0) = '1') else '1';

end RTL;

  