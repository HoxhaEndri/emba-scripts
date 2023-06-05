#! /bin/bash

result=$'Firmware Name;Parameters;OS Verified;Architecture;Verified Exploited;Booted;IP_DET;ICMP;NMAP;Versions Identified;User Emulation State;Files;Directories;Kernel Symbols;Kernel Version Orig;Kernel version stripped; Config extracted;Arch;End;\n'
mapfile -t dirs < <(find . -maxdepth 1 -type d)
unset dirs[0]
for dir in "${dirs[@]}"; do
    fw_name=$(find "$dir/csv_logs/" -name "f50_base_aggregator.csv" -exec grep "FW_path" {} \; | rev | cut -d"/" -f1 | rev | cut -d ";" -f1)
    if [ -n "$fw_name" ]
    then
        result+="$fw_name;"
    else
	result+=";"
    fi

    parameters=$(find "$dir/csv_logs/" -name "f50_base_aggregator.csv" -exec grep "^emba_command;" {} \; | rev | cut -d"/" -f1 | rev | cut -d ";" -f1 | cut -d ' ' -f2-)
    if [ -n "$parameters" ]
    then
        result+="$parameters;"
    else
	result+=";"
    fi

    OS=$(find "$dir/csv_logs/" -name "f50_base_aggregator.csv" -exec grep "^os_verified;" {} \; | cut -d";" -f2)
    if [ -n "$OS" ]
    then
        result+="$OS;"
    else
	result+=";"
    fi

    ARCH=$(find "$dir/csv_logs/" -name "f50_base_aggregator.csv" -exec grep "^architecture_verified;" {} \; | cut -d";" -f2)
    if [ -n "$ARCH" ]
    then
        result+="$ARCH;"
    else
	result+=";"
    fi

    VEREXP=$(find "$dir/csv_logs/" -name "f50_base_aggregator.csv" -exec grep "^verified_exploited;" {} \; | cut -d ";" -f2)
    if [ -n "$VEREXP" ]
    then
        result+="$VEREXP;"
    else
	result+="NA;"
    fi

    SYS=$(find "$dir/csv_logs/" -name "f50_base_aggregator.csv" -exec grep "^system_emulation_state;" {} \; | cut -d ";" -f2- )
    if [ -n "$SYS" ]
    then
        temp="${SYS::-1}"
	result+=$(echo "$temp" | cut -d';' -f1-4)
	result+=";"
    else
	result+=";;;;"
    fi

    VERID=$(find "$dir/csv_logs/" -name "f50_base_aggregator.csv" -exec grep "^versions_identified;" {} \; | cut -d ";" -f2)
    if [ -n "$VERID" ]
    then
        result+="$VERID;"
    else
	result+=";"
    fi

    USEMU=$(find "$dir/csv_logs/" -name "f50_base_aggregator.csv" -exec grep "^user_emulation_state;" {} \; | cut -d ";" -f2)
    if [ -n "$USEMU" ]
    then
        result+="$USEMU;"
    else
	result+=";"
    fi

    FILES=$(find "$dir/csv_logs/" -name "f50_base_aggregator.csv" -exec grep "^files;" {} \; | cut -d ";" -f2)
    if [ -n "$FILES" ]
    then
        result+="$FILES;"
    else
	result+=";"
    fi

    DIRS=$(find "$dir/csv_logs/" -name "f50_base_aggregator.csv" -exec grep "^directories;" {} \; | cut -d ";" -f2)
    if [ -n "$DIRS" ]
    then
        result+="$DIRS;"
    else
	result+=";"
    fi

    KERSYS=$(find "$dir/csv_logs/" -name "s24_kernel_bin_identifier.csv" -exec grep 'unblob_extracted' {} \; | rev | cut -d ";" -f4 | rev | sort -rn | head -1 |tr '\n' ' ')
    KERSYS_BINWALK=$(find "$dir/csv_logs/" -name "s24_kernel_bin_identifier.csv" -exec grep 'firmware_binwalk_emba' {} \; |  rev | cut -d ";" -f4 | rev | sort -rn | head -1 | tr '\n' ' ')
    if [ -n "$KERSYS" ]
    then
        result+="${KERSYS::-1};"
    elif [ -n "$KERSYS_BINWALK" ]
    then
	result+="$KERSYS_BINWALK;"
    else
	result+=";"
    fi

    KERVEROG=$(find "$dir/csv_logs/" -name "s24_kernel_bin_identifier.csv" -exec grep 'unblob_extracted' {} \; | tail -1 | cut -d ";" -f1)
    KERVEROG_BINWALK=$(find "$dir/csv_logs/" -name "s24_kernel_bin_identifier.csv" -exec grep 'firmware_binwalk_emba' {} \; | tail -1 | cut -d ";" -f1)
    if [ -n "$KERVEROG" ]
    then
        result+="$KERVEROG;"
    elif [ -n "$KERVEROG_BINWALK" ]
    then
	result+="$KERVEROG_BINWALK;"
    else
	result+=";"
    fi

    KERVERSTR=$(find "$dir/csv_logs/" -name "s24_kernel_bin_identifier.csv" -exec grep 'unblob_extracted' {} \; | tail -1 | cut -d ";" -f2)
    KERVERSTR_BINWALK=$(find "$dir/csv_logs/" -name "s24_kernel_bin_identifier.csv" -exec grep 'firmware_binwalk_emba' {} \; | tail -1 | cut -d ";" -f2)
    if [ -n "$KERVERSTR" ]
    then
        result+="'""$KERVERSTR;"
    elif [ -n "$KERVERSTR_BINWALK" ]
    then
	result+="'""$KERVERSTR_BINWALK;"
    else
	result+=";"
    fi

    CONFIG=$(find "$dir/csv_logs/" -name "s24_kernel_bin_identifier.csv" -exec grep '/logs/s24_kernel_bin_identifier/' {} \; | head -1 | rev | cut -d ";" -f3 | rev)
    if [ -n "$CONFIG" ]
    then
        result+="Y;"
    else
	result+="N;"
    fi

    AARCH=$(find "$dir/csv_logs/" -name "p99_prepare_analyzer.csv" -exec grep 'unblob_extracted' {} \; | head -1 | rev | cut -d ";" -f 2,3 | rev)
    AARCH_BINWALK=$(find "$dir/csv_logs/" -name "p99_prepare_analyzer.csv" -exec grep 'firmware_binwalk_emba' {} \; | head -1 | rev | cut -d ";" -f 2,3 | rev )
    if [ -n "$AARCH" ]
    then
	result+="$AARCH;"
    elif [ -n "$AARCH_BINWALK" ]
    then
	result+="$AARCH_BINWALK;"
    else
	result+=";"
    fi

    result+=$'\n'
done
#echo "$result"
echo "$result" > log.csv
