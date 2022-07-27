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
 * @file blink_led/main.c
 * @author Stephan Nolting
 * @brief Simple blinking LED demo program using the lowest 8 bits of the GPIO.output port.
 **************************************************************************/
#include <stdbool.h>
#include <neorv32.h>

#define MILLISECONDS  100000
#define ADC_BASE_ADDR 0xA0000000


/**********************************************************************//**
 * Main function; shows an incrementing 8-bit counter on GPIO.output(7:0).
 *
 * @note This program requires the GPIO controller to be synthesized.
 *
 * @return Will never return.
 **************************************************************************/

uint32_t data_buf = 0;

int main() {

  // This is a *minimal* example program.

  // clear GPIO output (set all bits to 0)
  neorv32_gpio_port_set(0);

  uint64_t now = 0;

  bool print_info = true;

  neorv32_uart0_setup(115200, PARITY_NONE, FLOW_CONTROL_NONE);

  now = neorv32_mtime_get_time();
  while (1) 
  {

    if((neorv32_mtime_get_time() - now) > (100 * MILLISECONDS))
    {
      now = neorv32_mtime_get_time();
      neorv32_gpio_pin_toggle(7); // increment counter and mask for lowest 8 bit
    }

    if(print_info)
    {
      print_info = false;
      neorv32_uart0_printf("Welcome!\n");
      data_buf = *((volatile uint32_t*) (ADC_BASE_ADDR));
      neorv32_uart0_printf("Data: 0x%x\n", data_buf);
      data_buf = *((volatile uint32_t*) (ADC_BASE_ADDR + 4));
      neorv32_uart0_printf("Data: 0x%x\n", data_buf);
      data_buf = *((volatile uint32_t*) (ADC_BASE_ADDR + 8));
      neorv32_uart0_printf("Data: 0x%x\n", data_buf);
      data_buf = *((volatile uint32_t*) (ADC_BASE_ADDR + 12));
      neorv32_uart0_printf("Data: 0x%x\n", data_buf);

      data_buf = *((volatile uint32_t*) (ADC_BASE_ADDR + 0x104));
      neorv32_uart0_printf("Bad Data: 0x%x\n", data_buf);
    }
  }

  // this should never be reached
  return 0;
}
