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

   -- CPU clock input
   adc_cpu_clk_i	: 	in std_logic;

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

  signal clk_spi_0		  :	std_logic := '0';
  signal clk_spi_1		  :	std_logic := '0';
  signal clk_spi_2		  :	std_logic := '0';
  signal clk_spi_prev		:	std_logic := '0';
  signal clk_ris_e		  :	std_logic := '0';

  -- Wishbone interface
  constant MEM_START		: std_ulogic_vector(31 downto 0) 	:= X"A0000000";
  constant MEM_STOP		  : std_ulogic_vector(31 downto 0) 	:= X"A0000100";
  signal read_req		    :	std_logic 	:= '0';
  signal prev_read_req	:	std_logic 	:= '0';
  signal write_req		  :	std_logic 	:= '0';
  signal prev_write_req	:	std_logic 	:= '0';

  -- ADC FIFO
  -- This is based very much on S. Nolting's FIFO module.
  signal FIFO_DEPTH		: natural := 256;
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

  -- Downsampler
  type downsampler_regs is array (0 to 3) of std_ulogic_vector(15 downto 0);
  type downsampler_t is record
    samples : downsampler_regs;
    reg_0   : std_ulogic_vector(15 downto 0);
    reg_1   : std_ulogic_vector(15 downto 0);
    output  : std_ulogic_vector(15 downto 0);
    cnt     : std_ulogic_vector(1 downto 0);
    rdy     : std_logic;
  end record;
  signal downsampler : downsampler_t;


  -- ADC Registers, control and status
  signal    adc_status          : std_ulogic_vector(31 downto 0);
  signal    adc_enable          : std_logic := '0';
  constant  ADC_ENABLE_BIT      : natural := 0;
  constant  ADC_FIFO_EMPTY_BIT  : natural := 1;
  constant  ADC_FIFO_FULL_BIT   : natural := 2;
  constant  ADC_FIFO_HALF_BIT   : natural := 3;
  constant  ADC_FIFO_LEVEL_L    : natural := 4;
  constant  ADC_FIFO_LEVEL_H    : natural := FIFO_IDX + ADC_FIFO_LEVEL_L;

begin
  
  adc_data_o <= '0';
  adc_enable <= adc_status(ADC_ENABLE_BIT);

  -- Main Clock divider
  -- CLK is 49.152 MHz
  -- SPI CLK is 3.072 (1/16th)
  adc_clk_o <= clk_div(3);
  process(adc_clk_i, adc_rst_i)
  begin
    if ((adc_rst_i = '1') or (adc_enable = '0')) then
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
    if ((adc_rst_i = '1') or (adc_enable = '0')) then
      adc_csn_o <= '1';
    else
      if rising_edge(adc_clk_i) then
        if (clk_div = "0011") then
          adc_csn_o <= '0';
        end if;
      end if;
    end if;
  end process;

  -- From here on we process data from the main CPU clock domain
  -- Detect rising edge on clock and 
  -- generate a pulse
  process(adc_cpu_clk_i)
  begin
    if rising_edge(adc_cpu_clk_i) then
      clk_spi_2 <= clk_div(3);
      clk_spi_1 <= clk_spi_2;
      clk_spi_0 <= clk_spi_1;
      clk_ris_e <= '0';
      if ((clk_spi_1 = '1') and (clk_spi_0 = '0'))then
        clk_ris_e <= '1';
      end if;
    end if;
  end process;

  -- On a clock rising edge:
  -- - Grab a new bit
  -- - Increment the bit counter
  process(adc_cpu_clk_i, adc_rst_i)
  begin
    if ((adc_rst_i = '1') or (adc_enable = '0')) then
      bit_cnt <= X"0";
      data_reg_i <= X"0000";
    else
      if rising_edge(adc_cpu_clk_i) then
          if (clk_ris_e = '1') then
            bit_cnt <= bit_cnt + 1;
            data_reg_i(15 downto 1) <= data_reg_i(14 downto 0);
            data_reg_i(0) <= adc_data_i;
          end if;
        end if;
      end if;
  end process;	
  
  -- Downsampling
  -- We'll convert from 192Kbits to 48kbits
  process(adc_cpu_clk_i, adc_rst_i)
  begin
    if ((adc_rst_i = '1') or (adc_enable = '0')) then
      for i in 0 to 3 loop
        downsampler.samples(i) <= X"0000";
      end loop;
      downsampler.reg_0 <= X"0000";
      downsampler.reg_1 <= X"0000";
      downsampler.output <= X"0000";
      downsampler.cnt <= "00";
      downsampler.rdy <= '0';
    else
      if rising_edge(adc_cpu_clk_i) then
        downsampler.rdy <= '0';
        if ((bit_cnt = X"0") and (clk_ris_e = '1')) then
          downsampler.cnt <= std_ulogic_vector(unsigned(downsampler.cnt) + 1);
          case downsampler.cnt is
            when "00" =>
              downsampler.rdy <= '1';
              downsampler.samples(0) <= data_reg_i;
              downsampler.output <= std_ulogic_vector(
                unsigned(downsampler.samples(3)) + 
                unsigned(downsampler.reg_1)
              );
            when "01" =>
              downsampler.samples(1) <= data_reg_i;
            when "10" =>
              downsampler.samples(2) <= data_reg_i;
              downsampler.reg_0 <= std_ulogic_vector(
                unsigned(downsampler.samples(0)) + 
                unsigned(downsampler.samples(1))
              );
            when "11" =>
              downsampler.samples(3) <= data_reg_i;
              downsampler.reg_1 <= std_ulogic_vector(
                unsigned(downsampler.samples(2)) + 
                unsigned(downsampler.reg_0)
              );
            when others => Null;
          end case;
        end if;

      end if;
    end if;
  end process;
  
  -- ADC FIFO
  -- The incoming data gets written to FIFO
  -- A flag is set when the level is above half (128 words)
  -- Fifo reads are mapped to MEM_START + 0 

  fifo.level <= std_ulogic_vector(unsigned(fifo.w_pnt) - unsigned(fifo.r_pnt));
  fifo.empty <= '1' when (fifo.level = X"00") else '0';
  fifo.full <= '1' when (fifo.level = X"FF") else '0';
  fifo.half <= '1' when (fifo.level > X"7F") else '0';
  
  -- Store the newly received 16bit word into the FIFO
  process(adc_cpu_clk_i, adc_rst_i, bit_cnt, clk_ris_e)
  begin
    if ((adc_rst_i = '1') or (adc_enable = '0')) then
      fifo.w_pnt <= X"00";
      fifo.we <= '0';
    else
      if rising_edge(adc_cpu_clk_i) then
        fifo.we <= '0';
        fifo.w_pnt <= fifo.w_pnt;
        if (downsampler.rdy = '1') then
        -- if ((bit_cnt = X"0") and (clk_ris_e = '1')) then
          if(fifo.level /= X"FF") then
            fifo.data(to_integer(unsigned(fifo.w_pnt(FIFO_IDX-1 downto 0)))) <= downsampler.output;
            fifo.we <= '1';
            fifo.w_pnt <= std_ulogic_vector(unsigned(fifo.w_pnt) + 1);
          end if;
        end if;
      end if;
    end if;
  end process;

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
    
  process(adc_cpu_clk_i)
  begin
    if adc_rst_i = '1' then
      wb_dat_o <= X"00000000";
      wb_ack_o <= '0';
      fifo.r_pnt <= X"00";
          adc_status <= X"00000000";
    else
      if rising_edge(adc_cpu_clk_i) then
        wb_ack_o <= '0';
        adc_status(ADC_ENABLE_BIT) <= adc_status(ADC_ENABLE_BIT);
        adc_status(ADC_FIFO_EMPTY_BIT) <= fifo.empty;
        adc_status(ADC_FIFO_FULL_BIT) <= fifo.full;
        adc_status(ADC_FIFO_HALF_BIT) <= fifo.half;
        adc_status(ADC_FIFO_LEVEL_H downto ADC_FIFO_LEVEL_L) <= fifo.level;
        fifo.r_pnt <= fifo.r_pnt;

        -- Handle reads
        prev_read_req <= read_req;
        if ((read_req = '1') and (prev_read_req = '0')) then
          if(wb_adr_i(3 downto 0) = X"0") then
            wb_ack_o <= '1';
            wb_dat_o <= adc_status;
          elsif(wb_adr_i(3 downto 0) = X"4") then
            wb_ack_o <= '1';
            if(fifo.level /= X"00") then
              wb_dat_o(15 downto 0) <= fifo.data(to_integer(unsigned(fifo.r_pnt(FIFO_IDX-1 downto 0))));
              fifo.r_pnt <= std_ulogic_vector(unsigned(fifo.r_pnt) + 1);
            end if;
          end if;
        end if;

        -- Handle writes
        prev_write_req <= write_req;
        if ((write_req = '1') and (prev_write_req = '0')) then
          if(wb_adr_i(3 downto 0) = X"0") then
            wb_ack_o <= '1';
            adc_status <= wb_dat_i;
          -- Ignore any other case
          end if;
        end if;
      end if;
    end if;
  end process;

end architecture; --adc
