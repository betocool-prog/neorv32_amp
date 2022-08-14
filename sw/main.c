// #################################################################################################
// # << NEORV32 - Blinking LED Demo Program >>                                                     #
// # ********************************************************************************************* #
// # BSD 3-Clause License                                                                          #
// #                                                                                               #
// # Copyright (c) 2022, Stephan Nolting. All rights reserved.                                     #
// #                                                                                               #
// # Redistribution and use in source and binary forms, with or without modification, are          #
// # permitted provided that the following conditions are met:                                     #
// #                                                                                               #
// # 1. Redistributions of source code must retain the above copyright notice, this list of        #
// #    conditions and the following disclaimer.                                                   #
// #                                                                                               #
// # 2. Redistributions in binary form must reproduce the above copyright notice, this list of     #
// #    conditions and the following disclaimer in the documentation and/or other materials        #
// #    provided with the distribution.                                                            #
// #                                                                                               #
// # 3. Neither the name of the copyright holder nor the names of its contributors may be used to  #
// #    endorse or promote products derived from this software without specific prior written      #
// #    permission.                                                                                #
// #                                                                                               #
// # THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS   #
// # OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF               #
// # MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE    #
// # COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,     #
// # EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE #
// # GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED    #
// # AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING     #
// # NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED  #
// # OF THE POSSIBILITY OF SUCH DAMAGE.                                                            #
// # ********************************************************************************************* #
// # The NEORV32 Processor - https://github.com/stnolting/neorv32              (c) Stephan Nolting #
// #################################################################################################


/**********************************************************************//**
 * @file neorv32_amp/main.c
 * @author Alberto Fahrenkrog
 * @brief Simple ADC program
 **************************************************************************/
#include <stdbool.h>
#include <neorv32.h>

#define MSECONDS  100000
#define USECONDS  100

/* ADC definitions */
#define ADC_BASE_ADDR       0xA0000000
#define ADC_ENABLE_BIT      0x00000001
#define ADC_FIFO_EMPTY_BIT  0x00000002
#define ADC_FIFO_FULL_BIT   0x00000004
#define ADC_FIFO_HALF_BIT   0x00000008
#define ADC_FIFO_LEVEL      0x00000FF0

/* DAC definitions */
#define DAC_BASE_ADDR       0xA0000100
#define DAC_ENABLE_BIT      0x00000001
#define DAC_FIFO_EMPTY_BIT  0x00000002
#define DAC_FIFO_FULL_BIT   0x00000004
#define DAC_FIFO_HALF_BIT   0x00000008
#define DAC_FIFO_LEVEL      0x00000FF0

/**********************************************************************//**
 * Main function;
 *
 * @note This program requires the GPIO controller to be synthesized.
 * @note This program requires the external memory controller to be synthesized.
 * @note This program requires UART0 to be synthesized.
 *
 * @return Will never return.
 **************************************************************************/

static volatile uint32_t data_buf = 0;
volatile uint32_t* adc_reg = 0;
volatile uint32_t* dac_reg = 0;

int main() {

  uint64_t now_ms = 0;
  uint32_t samples_rxd = 0;

  // clear GPIO output (set all bits to 0)
  neorv32_gpio_port_set(0);
  neorv32_uart0_setup(115200, PARITY_NONE, FLOW_CONTROL_NONE);

  now_ms = neorv32_mtime_get_time();

  adc_reg = ((volatile uint32_t*) (ADC_BASE_ADDR));
  dac_reg = ((volatile uint32_t*) (DAC_BASE_ADDR));
  adc_reg[0] = ADC_ENABLE_BIT;
  dac_reg[0] = DAC_ENABLE_BIT;
  while (1) 
  {

    if((neorv32_mtime_get_time() - now_ms) > (100 * MSECONDS))
    {
      now_ms = neorv32_mtime_get_time();
      neorv32_gpio_pin_toggle(7); // increment counter and mask for lowest 8 bit
      // neorv32_uart0_printf("Status: %x, Samples RXD: %d\n", adc_reg[0], samples_rxd);
    }

    // Check if FIFO is half full
    if(adc_reg[0] & ADC_FIFO_HALF_BIT)
    {
      // Read data out while possible
      neorv32_gpio_pin_set(8);
      for(uint32_t i=0; i < 128; i++)
      {
        dac_reg[1] = adc_reg[1] * 4;
        samples_rxd++;
      }
      neorv32_gpio_pin_clr(8);
    }
  }

  // this should never be reached
  return 0;
}
