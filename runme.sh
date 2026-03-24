#!/usr/bin/env bash

# [LICENSE]
#
# MIT License
#
# Copyright (c) 2026 Gianluca Filippini
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# [/LICENSE]

IP_ADDR_CAMERA="10.0.0.2"
IP_ADDR_PC="10.0.0.1"

CAMERA_SENSOR_TYPE="imx219"

##############################################################################
#       WARNING | do not modify code below this line | WARNING  
##############################################################################
VERSION="2.1.0"

SCRIPT=$(readlink -f $0)
SCRIPTPATH=`dirname $SCRIPT`

CAMERA_SENSOR_TYPES="imx219,ar0234,ar0822,imx678"
PIP_SMBUS2_FILE="smbus2-0.6.0-py2.py3-none-any.whl"

##
## MAIN
##

# Colors
GRAY="\e[90m"
RED="\e[31m"
YELLOW="\e[33m"
GREEN="\e[32m"
WHITE="\e[97m"
RESET="\e[0m"

echo -e
echo -e "${WHITE}******************************${RESET}"
echo -e "${WHITE} QB-ASTRIAL hwtest procedure${RESET}"
echo -e "${WHITE}       ver $VERSION${RESET}"
echo -e "${WHITE}******************************${RESET}"
echo -e

## ARGS VALIDATION
if [ $# -eq 1 ]; then
   CAMERA_SENSOR_TYPE = $1
fi

if [[ ",$CAMERA_SENSOR_TYPES," == *",$CAMERA_SENSOR_TYPE,"* ]]; then
   echo -e "${GREEN}[OK] Sensor $CAMERA_SENSOR_TYPE is supported${RESET}"
else
   echo -e "${RED}[ERROR] Sensor $CAMERA_SENSOR_TYPE is NOT supported${RESET}"
   echo -e "test procedure interrupted."
   exit 1
fi

##
## FILE INTEGRITY CHECK
##
echo -e "${WHITE}Running: file integrity check ...${RESET}"
FILE="$SCRIPTPATH/qb-astrial_hwtest.sh"
if [ -f $FILE ]; then
   echo -e "${GREEN}[OK]File $FILE exists.${RESET}"
else
   echo -e "${RED}[ERROR]File $FILE does not exist.${RESET}"
   echo -e "test procedure interrupted."
   exit
fi

FILE="$SCRIPTPATH/adc_test.py"
if [ -f $FILE ]; then
   echo -e "${GREEN}[OK]File $FILE exists.${RESET}"
else
   echo -e "${RED}[ERROR]File $FILE does not exist.${RESET}"
   echo -e "test procedure interrupted."
   exit
fi

FILE="$SCRIPTPATH/$PIP_SMBUS2_FILE"
if [ -f $FILE ]; then
   echo -e "${GREEN}[OK]File $FILE exists.${RESET}"
else
   echo -e "${RED}[ERROR]File $FILE does not exist.${RESET}"
   echo -e "test procedure interrupted."
   exit
fi

FILE="$SCRIPTPATH/detection_qbastrial_h8.tar"
if [ -f $FILE ]; then
   echo -e "${GREEN}[OK]File $FILE exists.${RESET}"
else
   echo -e "${RED}[ERROR]File $FILE does not exist.${RESET}"
   echo -e "test procedure interrupted."
   exit
fi

##
## STEP 1: ETH CONFIGURATION
##
echo
echo -e "${WHITE}Running: IP-ADDR manual configuration check ...${RESET}"

echo
echo -e "${WHITE}PC manual config:${RESET}"
echo -e "${WHITE}make sure your Linux PC client is connected to the same switch ${RESET}"
echo -e "${WHITE}of the camera with ip_address set to FIXED IP: ${RESET}"
echo
echo -e "${YELLOW}$IP_ADDR_PC/24 ${RESET}"

echo
read -p "Press ENTER to continue..."

if ping -c 3 -W 2 $IP_ADDR_PC > /dev/null 2>&1; then
    echo -e "${GREEN}[OK] PC is reachable${RESET}"
else
    echo -e "${RED}[ERROR] PC is NOT reachable${RESET}"
    echo -e "test procedure interrupted."
    exit    
fi

echo
echo -e "${WHITE}QB-ASTRIAL manual config${RESET}"
echo -e "${WHITE}open a serial terminal (PuTTY) and login as root to the device ${RESET}"
echo -e "${WHITE}set the device ip_address with the following command: ${RESET}"
echo
echo -e "${YELLOW}ip addr add $IP_ADDR_CAMERA/24 dev eth0 ${RESET}"
echo
read -p "Press ENTER to continue..."

if ping -c 3 -W 2 $IP_ADDR_CAMERA > /dev/null 2>&1; then
    echo -e "${GREEN}[OK] QB-ASTRIAL is reachable${RESET}"
else
    echo -e "${RED}[ERROR] QB-ASTRIAL is NOT reachable${RESET}"
    echo -e "test procedure interrupted."
    exit    
fi

echo
echo -e "${WHITE}Copying files ...${RESET}"

scp_check=$(scp -r "$SCRIPTPATH"/* root@"$IP_ADDR_CAMERA": 2>&1)
ret=$?

if [ $ret -ne 0 ]; then
    shopt -s nocasematch
    if [[ "$scp_check" =~ REMOTE[[:space:]]+HOST[[:space:]]+IDENTIFICATION[[:space:]]+HAS[[:space:]]+CHANGED ]]; then
       echo -e "${YELLOW}[WARNING] removing ssh fingerprint for $IP_ADDR_CAMERA${RESET}"
       
       ssh-keygen -f "/home/gfilippi/.ssh/known_hosts" -R "10.0.0.2"

        scp_check=$(scp -r "$SCRIPTPATH"/* root@"$IP_ADDR_CAMERA": 2>&1)
        ret=$?

        if [ $ret -ne 0 ]; then
          echo -e "${RED}[ERROR] SCP copy failed${RESET}"
          echo -e "test procedure interrupted."
          exit    
        else
           echo -e "${GREEN}[OK] file copy successfull${RESET}"
        fi
    fi
    shopt -u nocasematch

else
    echo -e "${GREEN}[OK] file copy successfull${RESET}"
fi



echo
echo -e "${WHITE}PC manual config:${RESET}"
echo -e "${WHITE}now open a SEPARATE shell on your Linux PC ${RESET}"
echo -e "${WHITE}and execute the gstreamer client for streaming test${RESET}"
echo -e "${WHITE}(if you already have it do not re-open a new one)${RESET}"
echo -e "${WHITE}from the qb-astrial test folder execute the command${RESET}"
echo
echo -e "${YELLOW}./qb-astrial_streaming_client.sh${RESET}"
echo

read -p "Press ENTER to continue..."

echo
echo -e "${WHITE}Executing QB-ASTRIAL hw/sw test ...${RESET}"
ssh root@$IP_ADDR_CAMERA 'cd && ./qb-astrial_hwtest.sh'
