#!/bin/bash

set -eux

rustup update

for program in nu nu_plugin_clipboard nu_plugin_formats nu_plugin_polars nu_plugin_query nu_plugin_inc nu_plugin_gstat ;
do
	echo "Installing ${program}"
	cargo install $program --locked;
done
echo "DONE installing nu"
