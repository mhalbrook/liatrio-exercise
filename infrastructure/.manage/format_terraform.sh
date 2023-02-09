#!/bin/bash

# ------------------------------------------ Description -------------------------------------------------#
# Script is used to apply formatting to Terraform modules in mass.
# Script can format all modules within the repository, or only modules within the current directory
#
# Maintainer: Mitch Halbrook
# --------------------------------------------------------------------------------------------------------#

# --------------------------------------------- Usage ----------------------------------------------------#
# Run the script with:
# source relative/path/to/script
# 
# Example
# source ../../.manage/format_terraform.sh
# This will apply formatting to all modules within the current working directory
#
# Options
# -all | Apply formatting to all Terraform Modules within the repository.
# --------------------------------------------------------------------------------------------------------#

# Set current and script directory to allow formatting all modules, or only ones in current directory
script_dir=$(dirname $(readlink -f ${0%/*}))
current_dir=$(pwd)

# if -all is used, use top-level directory and format all modules
if [[ "$1" == "-all" ]]; then 
    format_dir="$script_dir"
else 
    format_dir="$current_dir"
fi 

# go to the directory to format
cd "$format_dir"

# generate a list of all directories with a backend.tf file
dir=($(find . -type f -name '*providers.tf' | sed -r 's|/[^/]+$||' |sort |uniq))

# for each director, run terraform format, then return to the original directory
for i in "${dir[@]}"; do     
    echo "Applying tf formatting for $i"
    cd "$i"
    terraform fmt
    cd "$format_dir"
done

# return to the directory from which the script was run
cd "$current_dir"
