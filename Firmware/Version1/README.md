Carnivore Firmware Redesign
===========================

 **_NOTE:_**  This is work in progress!
 
Redesigned firmware for Carnivore with bigger EP2C8 FPGA.
The endgoal of this firmware is to implement MSX-Audio and OPL4 (moonsound) in addition to the original Carnivore features.

## Firmware design

- The firmware will be a fully synchronous design running on a single 100MHz clock
- Parts that like to run at 3.58MHz (like vm2413) will use a clock-enable and use multi-cycle timing constraints
- Avalon busses will be used for data transport, there will be separate busses for memory and I/O

## I/O map

|Address|R/W|Description|
|:--|:--|:--|
|0x7C-0x7D|W|FM-PAC|　　　　　　
|0x52|RW|Test register|

## Memory map subslot 0

|Address|R/W|Description|
|:--|:--|:--|
|0x4000-0xFFFF|R|Reserved|

## Memory map subslot 1

|Address|R/W|Description|
|:--|:--|:--|
|0x4000-0x7FFF|R|FM-PAC ROM|
|0x4000-0x7FFF|R|FM-PAC ROM|
|0x7FF4|W|Write YM-2413 register port|
|0x7FF5|W|write YM-2413 data port|
|0x7FF6|RW|activate OPLL I/O ports|
|0x7FF7|RW|ROM page|

## Memory map subslot 2

|Address|R/W|Description|
|:--|:--|:--|
|0x4000-0xFFFF|R|Reserved|

## Memory map subslot 3

|Address|R/W|Description|
|:--|:--|:--|
|0x4000-0xFFFF|R|Reserved|
