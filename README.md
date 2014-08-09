Keypadradio
===========

Webradio for Raspberry Pi (or similar) with keypad as controler

To compile keypad-decoder:  
`$ gcc keypad-decoder.c`  
`$ mv a.out keypad-decoder`

To run Keypadradio:  
`$ sudo ./keypadradio.sh`

Note: display.py is not included into this project and not released unter GPLv3
It is based on the script from  
 http://www.schnatterente.net/technik/raspberry-pi-32-zeichen-hitachi-hd44780-display  
and will be replaced with an self written script.
