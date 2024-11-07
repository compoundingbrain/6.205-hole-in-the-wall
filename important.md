activate python env with

`source ~/6205_python/bin/activate`

close the env with

`deactivate`

Use python 3.12

`python3.12 <command>`

to compile code:

`lab-bc run lab01 obj` from PSETs dir

to flash board:

> Make sure the board is on with the switch

`openFPGALoader -b arty_s7_50 final.bit`

to test code correctness without building

`iverilog -i -g2012 <filename>`

open pulseview with in lab computers with

`pulseview`
