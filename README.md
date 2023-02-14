# The NeoRV32 Amp

When I started this project, I figured the above was a good name. I suppose the scope has changed a little, but I'm not about to change it now. I will upate it when necessary.

## Introduction

The idea behind the NeoRV32 Amp was an ADC / DAC codec based on the Cyclone IV Terasic De0 Nano board, to be used inside a guitar effects preamplifier. The De0 Nano comes with an ADC chip, an external SDRAM chip and an external SPI flash chip. Using the correct controllers, they could be interfaced with the NeoRV32 CPU to add volatile and non-volatile storage.

The DAC is a bit trickier, but still an interesting exercise. The De0 Nano has no external DAC, but I've been toying with the idea of synthesizing an audio capable DAC using PDM (Pulse Density Modulation) as opposed to PWM (Pulse Width Modulation). In it's crudest form, the results are pretty neat, possibly good enough for guitar-amp audio quality. Higher end audio would require more processing, but I'm not there yet.

I'll add a few other interfaces as well, maybe even test this on another board, I have a Xilinx Arty7 floating around somewhere, but I'm mostly working on the De0 Nano for this.

Why the NeoRV32? It's extremely well documented and it's fairly easy to get started with. It has enough peripherals already, and the examples are very good. The examples range from everything from the most basic micro in VHDL to bootloader code and different memory spaces. Seldom have I seen such good documentation.

## Project Structure

This project has a few folders to make it seem less cluttered. The NeoRV32 code for the processor lives outside this project, one level above on a folder cloned from Github [The Original NeoRV32](https://github.com/stnolting/neorv32).

This project was created using Quartus 21.1 Lite Edition.

| Folder | Description |
|:-------|:------------|
| Top Level | The project's top level and Quartus configuration files |
| [adc](adc) | The ADC source and simulation files |
| [dac](dac) | The DAC source and simulation files |
| [fifo](fifo) | A simple fifo in VHDL |
| [pdm](pdm) | VHDL source code for PDM module and simulation files |
| [python](python) | Some helper python scripts |
| [sw](sw) | Test software written in C |

## Required Software

All work described here was done on a Linux machine, using Zorin 16 distribution. It seems to work very well with everything else I need, so why not, and the compilation runs fast enough.

* Quartus Lite Edition 21.1 (I'm guessing that slightly newer or older version will work too)
* Python 3.10 (Miniconda)
* The Risc-V GCC compiler (instructions to get it are [here](https://stnolting.github.io/neorv32/ug/#_software_toolchain_setup)) 
