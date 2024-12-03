#!/bin/bash

while getopts "hc:ub:" opt; do
  case $opt in
    h) 
        echo "Usage: $0 [-h] [-c <filename>] [-u] [-b <1/2>]"
        echo "  -h             Display this help message"
        echo "  -c <filename>  Check syntax of the passed in file"
        echo "  -u             Upload built code in hdl/obj/final.bit to connected FPGA"
        echo "  -b <1/2>       Build FPGA code for main FPGA (1) or secondary FPGA (2)"
        exit 0
        ;;
    b)
        if [ $OPTARG -eq "1" ]; then
            echo "Building main FPGA"
            macro_insert='`define MAIN'
        elif [ $OPTARG -eq "2" ]; then
            echo "Building secondary FPGA"
            macro_insert='`define SECONDARY'
        else 
            echo "ERROR: Invalid build argument: $OPTARG. Must be 1 (main FPGA) or 2 (secondary FPGA)."
            break
        fi  

        top_level_filename="$(dirname "$0")/hdl/top_level.sv"
        if [ ! -f $top_level_filename ]; then
            echo "ERROR: File $top_level_filename does not exist"
        else
            echo "Found top_level.sv at $top_level_filename"
        fi

        if [[ $(head -n 1 $top_level_filename) == *define* ]]; then
            echo "Removing pre-existing macro from top_level.sv"
            sed -i '1d' $top_level_filename
        fi

        echo "Rewriting top_level with macro"
        echo -e "$(echo $macro_insert)\n$(cat $top_level_filename)" > $top_level_filename

        echo -e "Building FPGA Code\n"
        lab-bc run $(dirname "$0") obj
        ;;
    c) 
        if [ -f $OPTARG ]; then
            echo "Checking syntax of $OPTARG"
            iverilog -i -g2012 $OPTARG
        else 
            echo "ERROR: File $OPTARG does not exist"
        fi
        ;;
    u)
        echo "Loading onto FPGA"
        openFPGALoader -b arty_s7_50 obj/final.bit
        ;;
  esac
done
