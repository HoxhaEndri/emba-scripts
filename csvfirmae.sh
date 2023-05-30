#! /bin/bash

result=$'Firmware Name;Analysis Software;Booted;ICMP;NMAP;IP_DET;Network Mode;\n'
mapfile -t dirs < <(find . -maxdepth 1 -type d)
unset dirs[0]
for dir in "${dirs[@]}"; do
    firmae_temp=$(find "$dir/" -name "emulator_online_results.log" -exec grep "FirmAE" {} \;)
    if [ -z "$firmae_temp" ]; then
        result+=";;;;;;;"$'\n'
    else
        fw_name=$(echo "$firmae_temp" | rev | cut -d"/" -f1 | rev | cut -d ";")
        echo "$fw_name"
    fi

