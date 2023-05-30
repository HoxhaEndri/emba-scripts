#! /bin/bash

result=$'Firmware Name;Analysis Software;Booted;ICMP;NMAP;IP_DET;Network Mode;\n'
mapfile -t dirs < <(find . -maxdepth 1 -type d)
unset dirs[0]
for dir in "${dirs[@]}"; do
    firmae_temp=$(find "$dir/" -name "emulator_online_results.log" -exec grep "FirmAE" {} \; | rev | cut -d"/" -f1 | rev)
    if [ -z "$firmae_temp" ]; then
        result+=";;;;;;;"$'\n'
    else
        fw_name=$(echo "$firmae_temp" | cut -d ";" -f1)
        software=$(echo "$firmae_temp" | cut -d ";" -f2)
        booted=$(echo "$firmae_temp" | cut -d ";" -f3)
        icmp=$(echo "$firmae_temp" | cut -d ";" -f4)
        nmap=$(echo "$firmae_temp" | cut -d ";" -f5)
        ip=$(echo "$firmae_temp" | cut -d ";" -f6)
        net=$(echo "$firmae_temp" | cut -d ";" -f7)
        result+="$fw_name;$software;$booted;$icmp;$nmap;$ip;$net;"$'\n'
    fi
done

echo "$result" > firmae.csv
