-- #################################################################################################
-- # << Simple FIFO                                      														 >>            #
-- # ********************************************************************************************* #
-- # BSD 3-Clause License                                                                          #
-- #                                                                                               #
-- # Copyright (c) 2021, Alberto Fahrenkrog. All rights reserved.                                  #
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
-- # Simple FIFO - Alberto Fahrenkrog                                     					               #
-- #################################################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity simple_fifo is
  port (
    -- FIFO --
    -- Interface to the TOP level
    fifo_rst_i		  :	in std_logic;

    -- FIFO clock inputs
    clk_input_port  : in  std_logic;
    clk_output_port :	in  std_logic;

    -- Data Interface
    data_input      : in  std_ulogic_vector(15 downto 0)        := (others => '0');
    data_output     : out std_ulogic_vector(15 downto 0)        := (others => 'U');

    -- Control and status signals
    wr_en           : in  std_logic;
    rd_en           : in  std_logic;
    empty           : out std_logic                             := '1';
    full            : out std_logic                             := '0';
    half            : out std_logic                             := '0';
    level           : out std_ulogic_vector(7 downto 0)  := (others => '0') -- fill count

  );
end entity;

architecture simple_fifo_rtl of simple_fifo is

  signal FIFO_DEPTH : natural                         := 256;
  signal FIFO_WIDTH :	natural                         := 16;
  signal FIFO_IDX   :	natural                         := (8 - 1); -- Log2 of FIFO_DEPTH - 1

  type mem is array (0 to FIFO_DEPTH-1) of std_ulogic_vector(FIFO_WIDTH-1 downto 0);
  signal data       : mem ;

  signal w_pnt      : integer range 0 to 255          := 0; -- write pointer
  signal r_pnt      : integer range 0 to 255          := 0 ; -- read pointer
  signal f_level    : integer range 0 to 255; -- fill count
  signal f_empty    : std_ulogic;
  signal f_full     : std_ulogic;
  signal f_half     : std_ulogic;
  
begin

  -- Output signals
  empty <= f_empty;
  full <= f_full;
  half <= f_half;
  level <= std_ulogic_vector(to_unsigned(f_level, 8));

  -- Fifo status signals
  f_level <= w_pnt - r_pnt;
  f_empty <= '1' when (f_level = 0) else '0';
  f_full <= '1' when (f_level = 255) else '0';
  f_half <= '1' when (f_level > 127) else '0';

  -- FIFO Write Pointer
  process(clk_input_port, fifo_rst_i, wr_en, f_level)
  begin
    if (fifo_rst_i = '1') then
      w_pnt <= 0;
    else
      if rising_edge(clk_input_port) then
        if (wr_en = '1') then
          if(f_level /= 255) then
            w_pnt <= w_pnt + 1;
          end if;
        end if;
      end if;
    end if;
  end process;

  -- FIFO Read Pointer
  process(clk_output_port, fifo_rst_i, f_level)
  begin
    if(fifo_rst_i = '1') then
      r_pnt <= 0;
    else
      if(rising_edge(clk_output_port)) then
        if(rd_en = '1') then 
          if (f_empty /= '0') then
            r_pnt <= r_pnt + 1;
          end if;
        end if;
      end if;
    end if;    
  end process;
  
  -- Trigger a write into the FIFO
  process(fifo_rst_i, clk_input_port, wr_en)
  begin
    if(fifo_rst_i /= '1') then
      if rising_edge(clk_input_port) then
          if(wr_en = '1') then
            data(w_pnt) <= data_input;
          end if;
      end if;
    end if;
  end process;

  -- Read data out from FIFO
  process(fifo_rst_i, clk_output_port, rd_en)
  begin
    if(fifo_rst_i /= '1') then
      if(rising_edge(clk_output_port)) then
        if(rd_en = '1') then
          data_output <= data(r_pnt);
        end if;
      end if;
    end if;
  end process;

end architecture; --simple_fifo
