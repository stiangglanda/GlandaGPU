#!/bin/bash

WORKDIR=$(pwd)

gnome-terminal -- zsh -lic "cd \"$WORKDIR\" && /home/stiangglanda/altera_lite/25.1std/questa_fse/bin/vsim"

