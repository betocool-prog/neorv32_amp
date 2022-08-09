-- #################################################################################################
-- # << DAC for the DE0 Nano 														 >>            #
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
-- # De0 Nano DAC for the NEORV32 processor - Alberto Fahrenkrog					               #
-- #################################################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dac is
  port (
   -- DAC --
   -- Interface to the TOP level
   dac_clk_i		: 	in std_logic; -- 49.152 MHz
   dac_rst_i		:	in std_logic;

   -- CPU clock input
   dac_cpu_clk_i	: 	in std_logic;

   -- Wishbone bus interface (available if MEM_EXT_EN = true) --
  --  wb_tag_i       : in std_ulogic_vector(02 downto 0); -- request tag
   wb_adr_i       : in std_ulogic_vector(31 downto 0) := (others => '0'); -- address
   wb_dat_i       : in  std_ulogic_vector(31 downto 0) := (others => 'U'); -- read data
   wb_dat_o       : out std_ulogic_vector(31 downto 0); -- write data
   wb_we_i        : in std_ulogic; -- read/write
   wb_sel_i       : in std_ulogic_vector(03 downto 0); -- byte enable
   wb_stb_i       : in std_ulogic; -- strobe
   wb_cyc_i       : in std_ulogic; -- valid cycle
   wb_ack_o       : out  std_ulogic := '0'; -- transfer acknowledge
   wb_err_o       : out  std_ulogic := '0'; -- transfer error
   
   -- DAC Output --
   dac_pwm_o		:	out std_logic	:= '1'
  );
end entity;

architecture dac_rtl of dac is
  
  signal clk_div		    : 	unsigned(9 downto 0) := (others => '0');

  -- Wishbone interface
  constant MEM_START	  : std_ulogic_vector(31 downto 0) 	:= X"A0000100";
  constant MEM_STOP		  : std_ulogic_vector(31 downto 0) 	:= X"A0000200";
  signal read_req		    : std_logic 	:= '0';
  signal prev_read_req	:	std_logic 	:= '0';
  signal write_req		  :	std_logic 	:= '0';
  signal prev_write_req	:	std_logic 	:= '0';

  -- DAC FIFO
  -- This is based very much on S. Nolting's FIFO module.
  signal FIFO_DEPTH		: 	natural := 256;
  signal FIFO_WIDTH		:	natural := 16;
  signal FIFO_IDX			:	natural := (8 - 1); -- Log2 of FIFO_DEPTH - 1

  type fifo_data_t is array (0 to FIFO_DEPTH-1) of std_ulogic_vector(FIFO_WIDTH-1 downto 0);
  type fifo_t is record
    we    : std_ulogic; -- write enable
    re    : std_ulogic; -- write enable
    w_pnt : std_ulogic_vector(FIFO_IDX downto 0); -- write pointer
    r_pnt : std_ulogic_vector(FIFO_IDX downto 0); -- read pointer
    level : std_ulogic_vector(FIFO_IDX downto 0); -- fill count
    data  : fifo_data_t; -- fifo memory
    empty : std_ulogic;
    full  : std_ulogic;
    half  : std_ulogic;
    end record;
  signal fifo : fifo_t;
  
  signal data_in  :std_ulogic_vector(FIFO_WIDTH-1 downto 0);

  -- DAC Registers, control and status
  signal    dac_status          : std_ulogic_vector(31 downto 0) := (others => '0');
  signal    dac_enable          : std_logic := '0';
  constant  DAC_ENABLE_BIT      : natural := 0;
  constant  DAC_FIFO_EMPTY_BIT  : natural := 1;
  constant  DAC_FIFO_FULL_BIT   : natural := 2;
  constant  DAC_FIFO_HALF_BIT   : natural := 3;
  constant  DAC_FIFO_LEVEL_L    : natural := 4;
  constant  DAC_FIFO_LEVEL_H    : natural := FIFO_IDX + DAC_FIFO_LEVEL_L;

  -- DAC Data out
  signal    get_sample          :std_logic;
  signal    load_shift_reg      :std_logic;
  signal    data_fifo_out       :std_ulogic_vector(FIFO_WIDTH-1 downto 0);
  signal    dac_pwm_level       :unsigned(9 downto 0);

begin
  
  dac_enable <= dac_status(DAC_ENABLE_BIT);

  -- Main Clock counter
  -- CLK is 49.152 MHz
  -- We can do 1024 counts for 48Khz
  process(dac_clk_i, dac_rst_i)
  begin
    if ((dac_rst_i = '1') or (dac_enable = '0')) then
      clk_div <= (others => '0');
    else
      if rising_edge(dac_clk_i) then
        clk_div <= clk_div + 1;
      end if;
    end if;
  end process;	
  
  -- DAC FIFO
  -- The outgoing data gets written to FIFO
  -- A flag is set when the level is above half (128 words)
  -- Fifo reads are mapped to MEM_START + 0

  fifo.level <= std_ulogic_vector(unsigned(fifo.w_pnt) - unsigned(fifo.r_pnt));
  fifo.empty <= '1' when (fifo.level = X"00") else '0';
  fifo.full <= '1' when (fifo.level = X"FF") else '0';
  fifo.half <= '1' when (fifo.level > X"7F") else '0';

  -- Handle MEM_EXT interface requests
  -- Read
  read_req <= '1' when (
    ((wb_adr_i >= MEM_START) and (wb_adr_i < MEM_STOP)) and
    (wb_we_i = '0') and
    (wb_stb_i = '1') and
    (wb_cyc_i = '1')
  ) else '0';
  -- Write
  write_req <= '1' when (
    ((wb_adr_i >= MEM_START) and (wb_adr_i < MEM_STOP)) and
    (wb_we_i = '1') and
    (wb_stb_i = '1') and
    (wb_cyc_i = '1')
  ) else '0';

  wb_err_o <= '0';
  
  process(dac_cpu_clk_i)
  begin
    if (dac_rst_i = '1') then
      wb_dat_o <= X"00000000";
      wb_ack_o <= '0';
      dac_status <= X"00000000";
      data_in <= X"0000";
      fifo.we <= '0';
    else
      if rising_edge(dac_cpu_clk_i) then
        dac_status(DAC_ENABLE_BIT) <= dac_status(DAC_ENABLE_BIT);
        dac_status(DAC_FIFO_EMPTY_BIT) <= fifo.empty;
        dac_status(DAC_FIFO_FULL_BIT) <= fifo.full;
        dac_status(DAC_FIFO_HALF_BIT) <= fifo.half;
        dac_status(DAC_FIFO_LEVEL_H downto DAC_FIFO_LEVEL_L) <= fifo.level;
        data_in <= data_in;
        fifo.we <= '0';
        wb_ack_o <= '0';

        -- Handle writes
        prev_write_req <= write_req;
        if ((write_req = '1') and (prev_write_req = '0')) then
          if(wb_adr_i(3 downto 0) = X"0") then
            wb_ack_o <= '1';
            dac_status <= wb_dat_i;
          elsif(wb_adr_i(3 downto 0) = X"4") then
            wb_ack_o <= '1';
            fifo.we <= '1';
            data_in <= wb_dat_i(FIFO_WIDTH-1 downto 0);
          -- Ignore any other case
          end if;
        end if;

        -- Handle reads
        prev_read_req <= read_req;
        if ((read_req = '1') and (prev_read_req = '0')) then
          if(wb_adr_i(3 downto 0) = X"0") then
            wb_ack_o <= '1';
            wb_dat_o <= dac_status;
          elsif(wb_adr_i(3 downto 0) = X"4") then
            wb_ack_o <= '1';
				    wb_dat_o(31 downto FIFO_WIDTH) <= (others => '0');
            wb_dat_o(FIFO_WIDTH-1 downto 0) <= data_in; -- Current DAC value
          -- Ignore any other case
          end if;
        end if;
      end if;
    end if;
  end process;

  -- Trigger a write into the FIFO
  process(dac_cpu_clk_i, dac_rst_i)
  begin
    if ((dac_rst_i = '1') or (dac_enable = '0')) then
      fifo.w_pnt <= X"00";
    else
      if rising_edge(dac_cpu_clk_i) then
        if (fifo.we = '1') then
          fifo.data(to_integer(unsigned(fifo.w_pnt(FIFO_IDX-1 downto 0)))) <= data_in;
          fifo.w_pnt <= std_ulogic_vector(unsigned(fifo.w_pnt) + 1);
        end if;
      end if;
    end if;
  end process;

  -- Stream the DAC data out
  -- We work this using the 49MHz clock
  -- Generate a pulse at 48 Khzprocess(dac_clk_i)
  process(dac_clk_i, dac_enable)
  begin
    if(dac_enable = '0') then
      get_sample <= '0';
    else
      if(rising_edge(dac_clk_i)) then
        get_sample <= '0';
        if(clk_div = 0) then
          get_sample <= '1';
        end if;
      end if;
    end if;    
  end process;

  -- Read data out from FIFO
  process(dac_clk_i, dac_enable)
  begin
    if(dac_enable = '0') then
      data_fifo_out <= (others => '0');
      fifo.r_pnt <= X"00";
    else
      data_fifo_out <= data_fifo_out;
      if(rising_edge(dac_clk_i)) then
        if((get_sample = '1') and (fifo.empty = '0')) then
          data_fifo_out <= fifo.data(to_integer(unsigned(fifo.r_pnt(FIFO_IDX-1 downto 0))));
          fifo.r_pnt <= std_ulogic_vector(unsigned(fifo.r_pnt) + 1);
        end if;
      end if;
    end if;    
  end process;

  dac_pwm_level <= unsigned(data_fifo_out(14 downto 5));

  -- Shift the data out from the shift register
  -- Load a new value when signalled
  process(dac_enable, clk_div)
  begin
    if(dac_enable = '0') then
      dac_pwm_o <= '0';
    else
      if(clk_div >= dac_pwm_level) then
        dac_pwm_o <= '0';
      else
        dac_pwm_o <= '1';
      end if;
    end if;    
  end process;

end architecture; --dac
