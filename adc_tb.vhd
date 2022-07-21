-- #################################################################################################
-- # << ADC Testbench for the DE0 Nano												 >>            #
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
-- # ADC Testbench for the DE0 Nano - Alberto Fahrenkrog					                       #
-- #################################################################################################

library ieee;
use ieee.std_logic_1164.all;

entity adc_tb is

end adc_tb;

architecture behav of adc_tb is

    -- Inputs
    signal adc_clk_i: std_logic; 
    signal adc_rst_i : std_logic;
    signal adc_data_i : std_logic;

    -- Outputs 
    signal adc_csn_o: std_logic; 
    signal adc_data_o : std_logic;
    signal adc_clk_o : std_logic;

    -- Timing
    constant clk_period: time := 20.34 ns;

begin
    -- connecting testbench signals with adc.vhd
    UUT : entity work.adc port map (
	 -- ADC --
	 -- Interface to the TOP level
	 adc_clk_i	=> adc_clk_i,
	 adc_rst_i	=> adc_rst_i,
	 adc_csn_o	=> adc_csn_o,
	 adc_data_o	=> adc_data_o,
	 adc_data_i => adc_data_i,
	 adc_clk_o	=> adc_clk_o
    );
    
      -- Clock process definition
  clk_process: process
  begin
    adc_clk_i <= '0';
    wait for clk_period/2;
    adc_clk_i <= '1';
    wait for clk_period/2;
  end process;

  adc_rst_i <= '1', '0' after 1 us;
    
end behav ;