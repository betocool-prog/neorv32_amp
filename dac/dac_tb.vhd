-- #################################################################################################
-- # << DAC Testbench for the DE0 Nano												                       >>            #
-- # ********************************************************************************************* #
-- # BSD 3-Clause License                                                                          #
-- #                                                                                               #
-- # Copyright (c) 2021, Alberto Fahrenkrog. All rights reserved.                                     #
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
-- # DAC Testbench for the DE0 Nano - Alberto Fahrenkrog					                       #
-- #################################################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dac_tb is

end dac_tb;

architecture behav of dac_tb is

  signal dac_clk_i		  : std_logic; -- 49.152 MHz
  signal dac_rst_i		  : std_logic;

  -- CPU clock input
  signal dac_cpu_clk_i	: std_logic;

  -- Wishbone bus interface (available if MEM_EXT_EN = true) --
  signal wb_adr_i       : std_ulogic_vector(31 downto 0)  := (others => '0'); -- address
  signal wb_dat_i       : std_ulogic_vector(31 downto 0)  := (others => 'U'); -- read data
  signal wb_dat_o       : std_ulogic_vector(31 downto 0);                       -- write data
  signal wb_we_i        : std_ulogic;                                            -- read/write
  signal wb_sel_i       : std_ulogic_vector(03 downto 0);                        -- byte enable
  signal wb_stb_i       : std_ulogic;                                            -- strobe
  signal wb_cyc_i       : std_ulogic;                                            -- valid cycle
  signal wb_ack_o       : std_ulogic                      := '0';             -- transfer acknowledge
  signal wb_err_o       : std_ulogic                      := '0';             -- transfer error
  
  -- DAC Output --
  signal dac_pdm_o		  : std_logic	                      := '0';

  -- Timing
  constant clk_period   : time := 20.34 ns;
  constant clk_cpu_period: time := 10 ns;

  -- Memory holding test data
  type mem16_t is array (natural range <>) of std_ulogic_vector(15 downto 0); -- memory with 16-bit entries

  constant MEM_START    : std_ulogic_vector(31 downto 0) 	:= X"A0000100";
  constant MEM_STOP     : std_ulogic_vector(31 downto 0) 	:= X"A0000200";
  signal mem_idx        : unsigned(7 downto 0) 	:= X"00";

  -- 48 16-bit samples, 1 KHz at 48KHz fs
  constant test_data : mem16_t := (
    x"7FFF", x"90B4", x"A120", x"B0FB",
    x"BFFF", x"CDEB", x"DA81", x"E58B",
    x"EED8", x"F640", x"FBA2", x"FEE6",
    x"FFFF", x"FEE6", x"FBA2", x"F640",
    x"EED8", x"E58B", x"DA81", x"CDEB",
    x"BFFF", x"B0FB", x"A120", x"90B4",
    x"7FFF", x"6F4A", x"5EDE", x"4F03",
    x"3FFF", x"3213", x"257D", x"1A73",
    x"1126", x"09BE", x"045C", x"0118",
    x"0000", x"0118", x"045C", x"09BE",
    x"1126", x"1A73", x"257D", x"3213",
    x"3FFF", x"4F03", x"5EDE", x"6F4A"
  );

    -- Data output signals
  	signal data_cnt 		:	unsigned(3 downto 0) := X"0";
  	signal bit_cnt 		  :	unsigned(3 downto 0) := X"0";
    signal data_reg     : std_ulogic_vector(15 downto 0)  := x"0000";
    signal dac_status   : std_ulogic_vector(31 downto 0)  := x"00000000";
    signal dac_level    : std_ulogic_vector(7 downto 0)   := x"00";

    -- State machine states
    type tstate is (reset, enable, idle, read_status, write_data);
    signal mem_state: tstate;
    signal prev_state: tstate;

begin
    -- connecting testbench signals with adc.vhd
    UUT : entity work.dac port map (
   dac_clk_i      => dac_clk_i,
   dac_rst_i      => dac_rst_i,
   dac_cpu_clk_i  => dac_cpu_clk_i,
   wb_adr_i       => wb_adr_i,
   wb_dat_i       => wb_dat_i,
   wb_dat_o       => wb_dat_o,
   wb_we_i        => wb_we_i,
   wb_sel_i       => wb_sel_i,
   wb_stb_i       => wb_stb_i,
   wb_cyc_i       => wb_cyc_i,
   wb_ack_o       => wb_ack_o,
   wb_err_o       => wb_err_o,
   dac_pdm_o      => dac_pdm_o
  );

    
  -- Clock process definition
  clk_process: process
  begin
    dac_clk_i <= '0';
    wait for clk_period/2;
    dac_clk_i <= '1';
    wait for clk_period/2;
  end process;  
  
  cpu_clk_process: process
  begin
    dac_cpu_clk_i <= '0';
    wait for clk_cpu_period/2;
    dac_cpu_clk_i <= '1';
    wait for clk_cpu_period/2;
  end process;

  dac_rst_i <= '1', '0' after 1 us;

  -- Main process, writes data to memory

  -- update dac_status
  dac_status <= wb_dat_o;
  dac_level <= dac_status(11 downto 4);
  
  dac_write_process: process(prev_state, mem_state, dac_cpu_clk_i, mem_idx)
  begin
    if (dac_rst_i = '1') then
      -- All is zero
      wb_adr_i <= x"00000000";
      wb_dat_i <= x"00000000";
      wb_we_i <= '0';
      wb_stb_i <= '0';
      wb_cyc_i <= '0';
      mem_state <= reset;
      mem_idx <= (others => '0');
    else
      if rising_edge(dac_cpu_clk_i) then
        wb_adr_i <= x"00000000";
        wb_dat_i <= x"00000000";
        wb_we_i <= '0';
        wb_stb_i <= '0';
        wb_cyc_i <= '0';
        mem_state <= reset;
        case mem_state is
          when reset =>
            mem_state <= enable;

          when enable =>
            mem_state <= idle;
            prev_state <= write_data;
            wb_adr_i <= MEM_START;
            wb_stb_i <= '1';
            wb_cyc_i <= '1';
            wb_we_i <= '1';
            wb_dat_i <= x"00000001";

          when idle =>
            if (prev_state = write_data) then
              mem_state <= read_status;
            elsif (prev_state = read_status) then
              mem_state <= write_data;
            end if;

          when read_status =>
            mem_state <= idle;
            prev_state <= read_status;
            -- Read status word
            wb_adr_i <= MEM_START;
            wb_stb_i <= '1';
            wb_cyc_i <= '1';

          when write_data =>
            mem_state <= idle;
            prev_state <= write_data;
            -- write data to DAC
            wb_adr_i <= std_ulogic_vector(unsigned(MEM_START) + 4);
            wb_stb_i <= '1';
            wb_cyc_i <= '1';
            wb_we_i <= '1';
            wb_dat_i(31 downto 16) <= (others => '0');
            wb_dat_i(15 downto 0) <= test_data(to_integer(mem_idx));
            mem_idx <= mem_idx + 1;
            if mem_idx = 47 then
              mem_idx <= X"00";
            end if;

          when others =>
            wb_adr_i <= x"00000000";
            wb_dat_i <= x"00000000";
            mem_state <= reset;
          end case;
      end if;
    end if;
  end process;
    
end behav ;