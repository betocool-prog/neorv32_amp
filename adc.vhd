-- #################################################################################################
-- # << ADC for the DE0 Nano 														 >>            #
-- # ********************************************************************************************* #
-- # BSD 3-Clause License                                                                          #
-- #                                                                                               #
-- # Copyright (c) 2021, Stephan Nolting. All rights reserved.                                     #
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
-- # De0 Nano ADC for the NEORV32 processor - Alberto Fahrenkrog					               #
-- #################################################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity adc is
  port (
	 -- ADC --
	 -- Interface to the TOP level
	 adc_clk_i		: 	in std_logic; -- 49.152 MHz
	 adc_rst_i		:	in std_logic;

	 -- Parallel data interface to TOP level (SLINK)
	 adc_par_dat_o	:	out std_ulogic_vector(15 downto 0);
	 adc_slink_we_o	:	out std_logic	:= '0';
	 adc_slink_lst_o:	out std_logic	:= '0';
	 adc_slink_rdy_i:	in std_logic;
	 
	 -- SPI interface to chip --
	 adc_csn_o		:	out std_logic	:= '1';
	 adc_data_o		:	out std_logic	:= '0';
	 adc_data_i		:	in std_logic;
	 adc_clk_o		:	out std_logic	:= '1'
  );
end entity;

architecture adc_rtl of adc is
	
	signal clk_div		: 	unsigned(3 downto 0) := "0000";
	signal bit_cnt 		:	unsigned(3 downto 0) := X"0";

	signal data_reg_i	:	std_ulogic_vector(15 downto 0) := X"0000";
	signal data_reg 	:	std_ulogic_vector(15 downto 0) := X"0000";

	signal clk_ris_e	:	std_logic := '0';
	-- signal w_en			:	std_logic := '0';
	
begin
	
	adc_data_o <= '0';

	-- Main Clock divider
	-- CLK is 49.152 MHz or so
	-- SPI CLK is 3.072 (1/16th)
	adc_clk_o <= clk_div(3);
	process(adc_clk_i, adc_rst_i)
	begin
		if adc_rst_i = '1' then
			clk_div <= "0000";
		else
			if rising_edge(adc_clk_i) then
				clk_div <= clk_div + 1;
			end if;
		end if;
	end process;

	-- Set CSN low to start
	process(adc_clk_i, adc_rst_i, clk_div)
	begin
		if adc_rst_i = '1' then
			adc_csn_o <= '1';
		else
			if rising_edge(adc_clk_i) then
				if (clk_div = "0011") then
					adc_csn_o <= '0';
				end if;
			end if;
		end if;
	end process;

	-- Detect rising edge on clock and 
	-- generate a pulse
	process(adc_clk_i, clk_div)
	begin
		if rising_edge(adc_clk_i) then
			clk_ris_e <= '0';
			if (clk_div = "1000") then
				clk_ris_e <= '1';
			end if;
		end if;
	end process;

	-- On a clock rising edge:
	-- - Grab a new bit
	-- - Increment the bit counter
	process(adc_clk_i, adc_rst_i)
	begin
		if adc_rst_i = '1' then
			bit_cnt <= X"0";
			data_reg_i <= X"0000";
		else
			if rising_edge(adc_clk_i) then
					if (clk_ris_e = '1') then
						bit_cnt <= bit_cnt + 1;
						data_reg_i(15 downto 1) <= data_reg_i(14 downto 0);
						data_reg_i(0) <= adc_data_i;
					end if;
				end if;
			end if;
	end process;

	-- Store the newly received 16bit word
	process(adc_clk_i, adc_rst_i, bit_cnt, clk_ris_e)
	begin
		if adc_rst_i = '1' then
			data_reg <= X"0000";
		else
			if rising_edge(adc_clk_i) then
				if ((bit_cnt = X"0") and (clk_ris_e = '1')) then
					data_reg <= data_reg_i;
				end if;
			end if;
		end if;
	end process;

	-- Write Enable
	-- process(adc_clk_i)
	-- begin
	-- 	if rising_edge(adc_clk_i) then
	-- 		adc_slink_we_o <= '0';
	-- 		if ((bit_cnt = X"F") and (clk_ris_e = '1') and (adc_slink_rdy_i = '1')) then
	-- 			adc_slink_we_o <= '1';
	-- 			adc_par_dat_o <= data_reg;
	-- 		end if;
	-- 	end if;
	-- end process;
	
	-- Write enable signal
	adc_slink_we_o <= '1' when ((bit_cnt = X"F") and (clk_ris_e = '1') and (adc_slink_rdy_i = '1')) else '0';
	adc_par_dat_o <= data_reg;
	adc_slink_lst_o <= '0';

end architecture; --adc
