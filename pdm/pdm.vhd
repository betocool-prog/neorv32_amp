-- #################################################################################################
-- # << PDM (Pulse Density Modulation) Module                                        >>            #
-- # ********************************************************************************************* #
-- # BSD 3-Clause License                                                                          #
-- #                                                                                               #
-- # Copyright (c) 2022, Alberto Fahrenkrog. All rights reserved.                                  #
-- #                                                                                               #
-- # Redistribution and use in source and binary forms, with or without modification, are          #
-- # permitted provided that the following conditions are met:                                     #
-- #                                                                                               #
-- # 1. Redistributions of source code must retain the above copyright notice, this list of        #
-- #    conditions and the following disclaimer.                                                   #
-- #                                                                                               #
-- # 2. Redistributions in binary form must reproduce the above copyright notice, this list of     #
-- #    conditions and the following disclaimer in the documentation and/or other materials        #
-- #    provided with the distribution.                                                            #
-- #                                                                                               #
-- # 3. Neither the name of the copyright holder nor the names of its contributors may be used to  #
-- #    endorse or promote products derived from this software without specific prior written      #
-- #    permission.                                                                                #
-- #                                                                                               #
-- # THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS   #
-- # OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF               #
-- # MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE    #
-- # COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,     #
-- # EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE #
-- # GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED    #
-- # AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING     #
-- # NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED  #
-- # OF THE POSSIBILITY OF SUCH DAMAGE.                                                            #
-- # ********************************************************************************************* #
-- # << PDM (Pulse Density Modulation) Module, Alberto Fahrenkrog                    >>            #
-- #################################################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pdm is
  port (
   clk_i    : in std_logic; -- 49.152 MHz
   data_i   : in std_ulogic_vector(15 downto 0); -- 16 bit data
   rstn_i   : in std_logic;

   pdm_out  : out std_logic
  );
end entity;

architecture pdm_rtl of pdm is
  
  -- PDM signals
  signal err: std_ulogic_vector(15 downto 0) :=  X"0000";
  signal y_out: std_ulogic_vector(15 downto 0) :=  X"0000";

begin

PDM_process: process(clk_i, rstn_i)
  begin
    if(rstn_i = '0') then
      pdm_out <= '0';
      err <= X"0000";
      y_out <= X"0000";
    else
      if(rising_edge(clk_i)) then
        if (unsigned(data_i) >= unsigned(err)) then
          pdm_out <= '1';
          y_out <= X"FFFF";
        else
          pdm_out <= '0';
          y_out <= X"0000";
        end if;
        err <= std_ulogic_vector(unsigned(err) + unsigned(y_out) - unsigned(data_i));
      end if;
    end if;    
  end process;

end architecture; --dac