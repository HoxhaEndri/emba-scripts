#!/bin/bash

FIRMWARE_BASE_PATH="/home/endri/Firmware2020/ASUS/"
LOG_PATH_BASE="/home/endri/LOGS2020_firmae/ASUS/"
#FIRMWARE_BASE_PATH="/home/m1k3/firmware_results/Firmware_images/dlink_encrypted"
#LOG_PATH_BASE="/home/m1k3/firmware_results/emba_logs_system_emulation_dlink_encrypted"
LOG_PATH_POST="$LOG_PATH_BASE"/summary.log
# log file for only the last results

EMBA_OPTS=( "-s" "-z" "-Q" "-E" "-r" "-t" "-m" "s24" "-m" "s25" "-m" "s26" "-m" "s115" "-m" "s116" "-m" "f20" "-m" "f50" "-y" "-j")

NR_FIRMWARES=1
FIRMWARE_FILES=()

main() {
  trap cleaner INT
  echo -e "[*] Importing some EMBA helpers"
  #shellcheck source=../helpers/helpers_emba_print.sh
  source ./helpers/helpers_emba_print.sh
  source ./helpers/helpers_emba_path.sh
  source ./modules/L10_system_emulation.sh
  if [[ $EUID -ne 0 ]] ; then
    print_output "[-] Privileges are not correct. Have you run the script with sudo?" "no_log"
    exit 1
  fi

  if ! [[ -x ./emba ]]; then
    print_output "[!] EMBA binary not found. Start this script from your EMBA installation directory" "no_log"
    exit 1
  fi

  if ! [[ -d "$LOG_PATH_BASE" ]]; then
    mkdir -p "$LOG_PATH_BASE"
  fi

  print_output "[*] log to $LOG_PATH_POST" "no_log"
  touch "$LOG_PATH_POST"

  emba_testing_sys_emul

  print_output "[*] $(print_date)Firmware analysis of firmware files in $ORANGE$FIRMWARE_BASE_PATH$NC finished" "no_log" | tee -a "$LOG_PATH_POST"
}

emba_testing_sys_emul() {
  print_output "" "no_log"
  print_output "[*] $(print_date)Searching for firmware files in $ORANGE$FIRMWARE_BASE_PATH$NC" "no_log" | tee -a "$LOG_PATH_POST"

  mapfile -t FIRMWARE_FILES_TMP < <(find $FIRMWARE_BASE_PATH -type f -size +1M)
  # lets shuffle the array to analyse them in a more interesting way:
  #FIRMWARE_FILES_TMP=( $(shuf -e "${FIRMWARE_FILES_TMP[@]}") )
  FIRMWARE_FILES=("${FIRMWARE_FILES_TMP[@]}")
  print_output "[*] Found $ORANGE${#FIRMWARE_FILES[@]}$NC firmware files" "no_log" | tee -a "$LOG_PATH_POST"

  for FIRMWARE_PATH in "${FIRMWARE_FILES[@]}"; do
    sub_module_title "$(basename "$FIRMWARE_PATH")" 2>/dev/null | tee -a "$LOG_PATH_POST"
    print_output "[*] $(print_date)Testing firmware: $ORANGE$NR_FIRMWARES$NC / $ORANGE${#FIRMWARE_FILES[@]}$NC" "no_log" | tee -a "$LOG_PATH_POST"
    print_output "[*] $(print_date)Testing firmware $ORANGE$FIRMWARE_PATH$NC" "no_log" | tee -a "$LOG_PATH_POST"

    LOG_PATH=$(basename "$FIRMWARE_PATH" | tr '.' '_' | tr '[:space:]' '_' | tr '[:cntrl:]' '_')
    LOG_PATH="$LOG_PATH_BASE"/"$LOG_PATH"

    if ! [[ -d "$LOG_PATH" ]]; then
      FW_PATH="$FIRMWARE_PATH"
      print_output "[*] $(print_date)Logging to directory $ORANGE$LOG_PATH$NC" "no_log" | tee -a "$LOG_PATH_POST"
      print_output "[*] $(print_date)FIRMWARE_PATH set to $ORANGE$FW_PATH$NC" "no_log" | tee -a "$LOG_PATH_POST"

      losetup -D
      dmsetup remove_all
      sleep 1

      #./emba -l "$LOG_PATH" -f "$FW_PATH" "${EMBA_OPTS[@]}"
      #if [[ -f "$LOG_PATH"/emulator_online_results.log ]]; then
      #  sed -i "s#^\/firmware#$FW_PATH#g" "$LOG_PATH"/emulator_online_results.log
      #fi
      losetup -D
      dmsetup remove_all

      firmae_checker
      losetup -D
      dmsetup remove_all

      firmadyne_checker
      losetup -D
      dmsetup remove_all

      print_output "[*] $(print_date)Finished firmware image $ORANGE$FIRMWARE_PATH$NC" "no_log" | tee -a "$LOG_PATH_POST"
      reset
    else
      print_output "[*] Firmware image $ORANGE$FIRMWARE_PATH$NC already tested" "no_log" | tee -a "$LOG_PATH_POST"
    fi
    ((NR_FIRMWARES+=1))
    print_bar "no_log" | tee -a "$LOG_PATH_POST"
  done
}

firmadyne_checker() {
  EXT_DIR="./external"
  LOG_PATH_firmadyne="$LOG_PATH"/firmadyne_checker
  LOG_FILE="$LOG_PATH"/firmadyne_checker.txt
  mkdir -p "$LOG_PATH_firmadyne"
  export FIRMADYNE_DIR="$EXT_DIR""/firmadyne"

  print_bar "" "no_log" | tee -a "$LOG_FILE"
  print_output "" "no_log" | tee -a "$LOG_FILE"
  print_output "[*] Running firmadyne on $ORANGE$FW_PATH$NC" "no_log" | tee -a "$LOG_FILE"

  local IID
  export NETWORK_MODE="NONE"
  export ICMP="not ok"
  export TCP_0="not ok"
  export TCP="not ok"
  export BOOTED="NONE"

  /etc/init.d/postgresql restart

  # check for old emulation processes and exit if the scratch dir is not empty
  OLD_FIRMAE_CNT=$(find "$FIRMADYNE_DIR"/scratch -maxdepth 1 -type d | wc -l)

  if [[ "$OLD_FIRMAE_CNT" -gt 1 ]]; then
    print_output "[-] Found old emulation processes. We delete these files now!" "no_log" | tee -a "$LOG_FILE"
    rm -r "$FIRMADYNE_DIR"/scratch/*
  fi

  ORIG_PATH=$(pwd)
  FIRMWARE_PATH_orig="$(abs_path "$FW_PATH")"
  FIRMWARE_NAME=$(basename "$FW_PATH")

  cd "$FIRMADYNE_DIR" || exit
  recreate_firmadyne_db

  print_output "[*] Firmadyne firmware extractor running ..." "no_log" | tee -a "$LOG_FILE"
  
  PGPASSWORD=firmadyne timeout --preserve-status --signal SIGINT 240 python3 ./sources/extractor/extractor.py -b "${FIRMWARE_NAME}_firmadyne" -sql 127.0.0.1 -np -nk "$FIRMWARE_PATH_orig" images | tee -a "$LOG_FILE"

  IID=$(grep "Database Image ID:" "$LOG_FILE" | awk '{print $5}' || true)

  if [[ -f ./images/"${IID}".tar.gz ]]; then

    print_output "[*] Firmadyne firmware architecture detection running ..." "no_log" | tee -a "$LOG_FILE"
    PGPASSWORD=firmadyne ./scripts/getArch.sh ./images/"${IID}".tar.gz | tee -a "$LOG_FILE"
    PGPASSWORD=firmadyne ./scripts/tar2db.py -i "${IID}" -f ./images/"${IID}".tar.gz | tee -a "$LOG_FILE"

    print_output "[*] Firmadyne firmware image building running ..." "no_log" | tee -a "$LOG_FILE"
    echo "firmadyne" | PGPASSWORD=firmadyne ./scripts/makeImage.sh "${IID}" || true | tee -a "$LOG_FILE"
    print_output "[*] Firmadyne network identification running ..." "no_log" | tee -a "$LOG_FILE"
    PGPASSWORD=firmadyne ./scripts/inferNetwork.sh "${IID}" || true | tee -a "$LOG_FILE"
    mapfile -t IPS < <(grep "Interfaces:" "$LOG_FILE" | awk '{print $3}' | cut -d\' -f2 | grep "[0-9]" || true)
    IPS+=( "$(grep "sudo ip route add" ./scratch/"${IID}"/run.sh | awk '{print $5}' || true)" )
    eval "IPS=($(for i in "${IPS[@]}" ; do echo "\"$i\"" ; done | sort -u))"
    NMAP_LOG="nmap_firmadyne.txt"
    IP_ADDRESS_="NONE"

    if [[ -f ./scratch/"${IID}"/run.sh ]] && [[ "${#IPS[@]}" -gt 0 ]]; then
      for IP in "${IPS[@]}";do
        if echo "$IP" | grep -q "[0-9]"; then
          print_output "[*] Starting firmadyne emulation for IP $ORANGE$IP$NC" "no_log" | tee -a "$LOG_FILE"
          ./scratch/"${IID}"/run.sh | tee -a "$LOG_FILE" &
          sleep 60
          NMAP_LOG="nmap_firmadyne.txt"
          export IP_ADDRESS_
          IP_ADDRESS_="$IP" # just a quick hack for the check_online_stat_ae function
          check_online_stat_ae
          print_output "[*] Finished firmadyne emulation for IP $ORANGE$IP$NC" "no_log" | tee -a "$LOG_FILE"
        fi
      done
    elif [[ "${#IPS[@]}" -eq 0 ]]; then
      print_output "[-] No IP address detected." "no_log" | tee -a "$LOG_FILE"
    else
      print_output "[-] firmadyne run script not generated." "no_log" | tee -a "$LOG_FILE"
    fi

    if grep -q -E "Host with .* is reachable via ICMP." "$LOG_FILE"; then
      ICMP="ok"
      BOOTED="yes"
    fi
    if grep -q -E "Host with .* is reachable on TCP port 0 via hping." "$LOG_FILE"; then
      TCP_0="ok"
      BOOTED="yes"
    fi
    if grep -q "tcp.*open" "$LOG_PATH_MODULE"/"$NMAP_LOG" 2>/dev/null; then
      TCP="ok"
      BOOTED="yes"
    fi

    print_output "[*] Copy firmadyne data to $ORANGE$LOG_PATH_MODULE$NC" "no_log" | tee -a "$LOG_FILE"
    cp -r ./scratch/"${IID}"/* "$LOG_PATH_MODULE"/

    PGPASSWORD=firmadyne ./scripts/delete.sh "$IID" | tee -a "$LOG_FILE"

    if losetup | grep -q "scratch/${IID}"; then
      losetup -d "$(losetup | grep "scratch/${IID}" | awk '{print $1}')" || true
    fi

  else
    print_output "[!] Firmadyne extractor failed" "no_log" | tee -a "$LOG_FILE"
  fi

  export RESULT_SOURCE="firmadyne"
  echo "$FIRMWARE_PATH_orig;$RESULT_SOURCE;Booted $BOOTED; ICMP $ICMP; TCP-0 $TCP_0;TCP $TCP; IP address: $IP_ADDRESS_; Network mode: $NETWORK_MODE" >> "$LOG_PATH"/emulator_online_results.log

  losetup -D

  cd "$ORIG_PATH" || exit
  print_bar "" "no_log" | tee -a "$LOG_FILE"
}

firmae_checker() {

  LOG_PATH_AE="$LOG_PATH"/firmae_checker
  LOG_FILE="$LOG_PATH"/firmae_checker.txt
  mkdir -p "$LOG_PATH_AE"
  #EXT_DIR="./external"
  export FIRMAE_DIR="/home/endri/FirmAE"
  local IID
  export NETWORK_MODE="NONE"
  export ICMP="not ok"
  export TCP_0="unknown"
  export TCP="not ok"
  export BOOTED="NONE"

  ORIG_PATH=$(pwd)

  FIRMWARE_PATH_orig="$(abs_path "$FW_PATH")"
  FIRMWARE_NAME=$(basename "$FW_PATH")

  print_bar "" "no_log" | tee -a "$LOG_FILE"
  print_output "" "no_log" | tee -a "$LOG_FILE"
  print_output "[*] Running FirmAE on $ORANGE$FW_PATH$NC" "no_log" | tee -a "$LOG_FILE"

  # check for old emulation processes and exit if the scratch dir is not empty
  OLD_FIRMAE_CNT=$(find "$FIRMAE_DIR"/scratch -maxdepth 1 -type d | wc -l)

  cd "$FIRMAE_DIR" || exit

  if [[ "$OLD_FIRMAE_CNT" -gt 1 ]]; then
    print_output "[-] Found old emulation processes. We delete these files now!" "no_log" | tee -a "$LOG_FILE"
    mapfile -t OLD_IIDS < <(find ./scratch/ -maxdepth 1 -type d -exec basename {} \; | grep "[0-9]")
    for OLD_IID in "${OLD_IIDS[@]}"; do
      PGPASSWORD=firmadyne ./scripts/delete.sh "$OLD_IID" | tee -a "$LOG_FILE"
    done
  fi
  rm -r ./scratch/*

  /etc/init.d/postgresql restart

  recreate_firmadyne_db

  ./run.sh -c "${FIRMWARE_NAME}_firmae" "$FIRMWARE_PATH_orig" | tee -a "$LOG_FILE"

  if grep -q "extractor.py failed" "$LOG_FILE"; then
    # extractor failed hard ... do it again
    ./run.sh -c "${FIRMWARE_NAME}_firmae" "$FIRMWARE_PATH_orig" | tee -a "$LOG_FILE"
  fi

  if ! grep -q "extractor.py failed" "$LOG_FILE"; then
    IID=$(grep IID "$LOG_FILE" | awk '{print $2}' || true)

    if grep -q "Network reachable on" "$LOG_FILE"; then
      ICMP="ok"
      BOOTED="yes"
    fi
    if grep -q "Web service on" "$LOG_FILE"; then
      TCP="ok"
      BOOTED="yes"
    fi

    if [[ -f ./scratch/"${IID}"/run.sh ]]; then
      print_output "[*] FirmAE startup script:" "no_log" | tee -a "$LOG_FILE"
      tee -a "$LOG_FILE" < ./scratch/"${IID}"/run.sh
      NETWORK_MODE=$(grep "/image/firmadyne/network_type" ./scratch/"${IID}"/run.sh | cut -d\" -f2)
      print_output "[*] Copy FirmAE data to $ORANGE$LOG_PATH_AE$NC"
      export IP_ADDRESS_
      if [[ -f ./scratch/"${IID}"/ip ]]; then
        IP_ADDRESS_=$(cat ./scratch/"${IID}"/ip)
      else
        IP_ADDRESS_="NONE"
      fi
      cp -r ./scratch/"${IID}"/* "$LOG_PATH_AE"/
    fi

    if [[ -n "${IID}" ]]; then
      PGPASSWORD=firmadyne ./scripts/delete.sh "$IID" | tee -a "$LOG_FILE"
    fi
  fi

  export RESULT_SOURCE="FirmAE"
  echo "$FIRMWARE_PATH_orig;$RESULT_SOURCE;Booted $BOOTED; ICMP $ICMP; TCP-0 $TCP_0;TCP $TCP; IP address: $IP_ADDRESS_; Network mode: $NETWORK_MODE" >> "$LOG_PATH"/emulator_online_results.log

  losetup -D

  cd "$ORIG_PATH" || exit
  print_bar "" "no_log" | tee -a "$LOG_FILE"
}

recreate_firmadyne_db() {
  print_output "[*] Dropping firmware database" "no_log" | tee -a "$LOG_FILE"
  sudo -u postgres dropdb firmware | tee -a "$LOG_FILE"
  print_output "[*] Creating firmware database" "no_log" | tee -a "$LOG_FILE"
  sudo -u postgres createdb -O firmadyne firmware | tee -a "$LOG_FILE"
  print_output "[*] Building firmware database" "no_log" | tee -a "$LOG_FILE"
  # shellcheck disable=SC2024
  sudo -u postgres psql -d firmware < ./database/schema | tee -a "$LOG_FILE"
}


print_date() {
  echo "$ORANGE$(date)$NC - "
}

cleaner() {
  print_output "[*] User interrupt detected!" "no_log"
  #kill "$check_cve_job_pid"
  exit 1
}

main "$@"
