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

STREAMING_DURATION="20s"

##############################################################################
#       WARNING | do not modify code below this line | WARNING  
##############################################################################
VERSION="2.1.0"

SCRIPT=$(readlink -f $0)
SCRIPTPATH=`dirname $SCRIPT`

CAMERA_SENSOR_TYPES="imx219,ar0234,ar0822,imx678"
PIP_SMBUS2_FILE="smbus2-0.6.0-py2.py3-none-any.whl"

APPS_PATH="/root/apps"
APP_PATH="detection"
APP_CMD="detection.sh"
APP_CHECK="qb_astrial.txt"

# pwm fan control
PWM_CHIP=0
PWM_CHANNEL=0
PWM_FREQUENCY=100 # 100kHz
PWM_BASE="/sys/class/pwm/pwmchip${PWM_CHIP}"
PWM_PATH="${PWM_BASE}/pwm${PWM_CHANNEL}"
PWM_DUTY_CYCLE_MIN=0
PWM_DUTY_CYCLE_MAX=100


## ###########################################################################
## tools
## ###########################################################################

initialize_pwm() {
    echo "Initializing PWM${PWM_CHIP}..."
    
    # Check if PWM chip exists
    if [ ! -d "$PWM_BASE" ]; then
        echo -e "${RED}ERROR: PWM chip $PWM_CHIP not found at $PWM_BASE ${RESET}"
        exit 1
    fi
    
    # Export PWM channel if not already exported
    if [ ! -d "$PWM_PATH" ]; then
        echo $PWM_CHANNEL > "${PWM_BASE}/export"
        sleep 0.5
    fi
    
    # Calculate period in nanoseconds
    # Period = 1,000,000,000 / frequency
    PWM_PERIOD=$((1000000000 / PWM_FREQUENCY))
    
    # Set period
    echo $PWM_PERIOD > "${PWM_PATH}/period"
    
    # Set initial duty cycle to minimum
    duty_ns=$(echo "scale=0; $PWM_PERIOD * $PWM_DUTY_CYCLE_MIN / 100" | bc)
    echo $duty_ns > "${PWM_PATH}/duty_cycle"
    
    # Enable PWM
    echo 1 > "${PWM_PATH}/enable"
    
    echo -e "${GREEN}PWM initialized: ${PWM_FREQUENCY}Hz, Period: ${PWM_PERIOD}ns ${RESET}"
}

set_duty_cycle() {
    local duty_percent=$1
    
    # Clamp duty cycle between min and max
    if (( $(echo "$duty_percent < $PWM_DUTY_CYCLE_MIN" | bc -l) )); then
        duty_percent=$PWM_DUTY_CYCLE_MIN
    elif (( $(echo "$duty_percent > $PWM_DUTY_CYCLE_MAX" | bc -l) )); then
        duty_percent=$PWM_DUTY_CYCLE_MAX
    fi
    
    # Calculate duty cycle in nanoseconds
    duty_ns=$(echo "scale=0; $PWM_PERIOD * $duty_percent / 100" | bc)
    
    # Set duty cycle
    echo $duty_ns > "${PWM_PATH}/duty_cycle"
 }

## ###########################################################################
## MAIN
## ###########################################################################


# Colors
GRAY="\e[90m"
RED="\e[31m"
YELLOW="\e[33m"
GREEN="\e[32m"
WHITE="\e[97m"
RESET="\e[0m"

export DISPLAY=:0

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

##
## SOFTWARE CONFIGURATION
##
echo -e "${WHITE}Running: sw configuration check ...${RESET}"

pip_check=`pip3 list | grep smbus2`

regex_pattern="smbus2"

if [[ "$pip_check" =~ $regex_pattern ]]; then
   echo -e "${GREEN}[OK] python package SMBUS is installed${RESET}"
else
   echo -e "${RED}[ERROR] missing python pkg SMBUS2, installing...${RESET}"
   pip3 install ./$PIP_SMBUS2_FILE

   # check again
   pip_check=`pip3 list | grep smbus2`
   if [[ "$pip_check" =~ $regex_pattern ]]; then
      echo -e "${GREEN}[OK] python package SMBUS is now installed${RESET}"
   else
      echo -e "${RED}[ERROR]Could not install python package SMBUS${RESET}"
      echo -e "please manually check your pip3 environment"
      echo -e "test procedure interrupted."
      exit
   fi
fi


##
## SOFTWARE CONFIGURATION
##

echo -e "${WHITE}Running: eth configuration check ...${RESET}"

ip addr add $IP_ADDR_CAMERA/24 dev eth0

if ping -c 3 -W 2 $IP_ADDR_CAMERA > /dev/null 2>&1; then
    echo -e "${GREEN}[OK] QB-ASTRIAL is reachable${RESET}"
else
    echo -e "${RED}[ERROR] QB-ASTRIAL is NOT reachable${RESET}"
    echo -e "test procedure interrupted."
    exit    
fi

if ping -c 3 -W 2 $IP_ADDR_PC > /dev/null 2>&1; then
    echo -e "${GREEN}[OK] PC is reachable${RESET}"
else
    echo -e "${RED}[ERROR] PC is NOT reachable${RESET}"
    echo -e "test procedure interrupted."
    exit    
fi

##
## HARDWARE CONFIGURATION
##
echo -e "${WHITE}Running: hw configuration check ...${RESET}"

# verify test connector is inserted

i2cdetect_reference="\
     0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f\
00:                         -- -- -- -- -- -- -- -- \
10: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- \
20: -- -- -- -- -- -- -- -- -- -- -- -- -- -- 2e -- \
30: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- \
40: -- -- -- -- -- -- -- -- 48 -- -- -- -- -- -- -- \
50: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- \
60: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- \
70: -- -- -- -- -- -- -- -- "

i2cdetect_reference=${i2cdetect_reference//$'\n'/}
i2cdetect_reference=${i2cdetect_reference// +$/}
i2cdetect_reference="${i2cdetect_reference%"${i2cdetect_reference##*[![:space:]]}"}"

i2cdetect_check=`i2cdetect -r -y 4`
i2cdetect_check=${i2cdetect_check//$'\n'/}
i2cdetect_check="${i2cdetect_check%"${i2cdetect_check##*[![:space:]]}"}"

if [ "$i2cdetect_reference" == "$i2cdetect_check" ]; then
   echo -e "${GREEN}[OK] QB-ASTRIAL test test dongle is inserted${RESET}"
else
   echo -e "${RED}[ERROR] missing QB-ASTRIAL test dongle on M8 connector or wrong I2C addressing${RESET}"
   echo -e
   i2cdetect -r -y 4
   echo -e
   echo -e "test procedure interrupted."
   exit
fi


## make sure we export all features from the specific dts
##

#cd /var/run/media/boot-mmcblk2p1
#dts_check=`diff -qs imx8mp-astrial.dtb imx8mp-astrial-enable-all.dtb`

#regex_pattern="differ"
#if [[ "$dts_check" =~ $regex_pattern ]]; then
#   echo -e "Switching DTS to export all PWM functionalities"
#   cp imx8mp-astrial.dtb imx8mp-astrial.dtb.ORIG
#   cp imx8mp-astrial-enable-all.dtb imx8mp-astrial.dtb
#   sleep 1
#   exit
#   echo -e "Now rebooting to enable the configuration"
#   sleep 2
#   sync
#   sync
#   reboot
#   exit
#fi

##
## HARDWARE TESTS
##

## back to the home root folder
cd $SCRIPTPATH

i2c_check=`python3 ./adc_test.py`

if [[ "$i2c_check" == "1" ]]; then
   echo -e "${GREEN}[OK] I2C test passed${RESET}"
else
   echo -e "${RED}[ERROR] I2C test failed${RESET}"
   echo -e "test procedure interrupted."
   exit
fi

## fan testing
initialize_pwm
echo -e "Test FAN: turning ON for 6 seconds ..."
set_duty_cycle 100
sleep 1
echo -e "${YELLOW} >>> Please VERIFY that fan is: ON${RESET}"
sleep 5
set_duty_cycle 0
sleep 1
echo -e "${YELLOW} >>> Please VERIFY that fan is: OFF${RESET}"
sleep 3

## pwm && gpio testing
GPIO_PWM_CHIP=1
GPIO_PWM_CHANNEL=0
GPIO_CHIP=gpiochip1
GPIO_LINE=1

TARGET_COUNT=7        # number of HIGH detections
POLL_INTERVAL=0.1     # 100 ms
TIMEOUT=10            # seconds

echo -e "Test PWM blink (fast) ..."
sleep 1

# Start PWM
echo -e 0 > /sys/class/pwm/pwmchip${GPIO_PWM_CHIP}/export
echo -e 300000000 > /sys/class/pwm/pwmchip${GPIO_PWM_CHIP}/pwm${GPIO_PWM_CHANNEL}/period
echo -e 100000000 > /sys/class/pwm/pwmchip${GPIO_PWM_CHIP}/pwm${GPIO_PWM_CHANNEL}/duty_cycle
echo -e 1 > /sys/class/pwm/pwmchip${GPIO_PWM_CHIP}/pwm${GPIO_PWM_CHANNEL}/enable

echo -e "${GRAY}Polling GPIO for HIGH levels (timeout: ${TIMEOUT}s)...${RESET}"

count=0
start_time=$(date +%s)

while true; do
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))

    # Check timeout
    if [ "$elapsed" -ge "$TIMEOUT" ]; then
        echo -e "${GRAY}Timeout reached (${TIMEOUT}s)${RESET}"
        break
    fi

    # Check if target reached
    if [ "$count" -ge "$TARGET_COUNT" ]; then
        echo -e "${GRAY}Target reached ($count/$TARGET_COUNT)${RESET}"
        break
    fi

    value=$(gpioget ${GPIO_CHIP} ${GPIO_LINE})

    if [ "$value" -eq 1 ]; then
        count=$((count + 1))
        echo -e "${GRAY}HIGH detected ($count/$TARGET_COUNT)${RESET}"

        # Wait until it goes LOW (avoid multiple counts)
        while [ "$(gpioget ${GPIO_CHIP} ${GPIO_LINE})" -eq 1 ]; do
            sleep $POLL_INTERVAL
        done
    fi

    sleep $POLL_INTERVAL
done

echo -e "Final HIGH count: $count"

echo -e "${GRAY}Stopping PWM...${RESET}"

# Stop PWM
echo -e 0 > /sys/class/pwm/pwmchip${GPIO_PWM_CHIP}/pwm${GPIO_PWM_CHANNEL}/enable
echo -e 0 > /sys/class/pwm/pwmchip${GPIO_PWM_CHIP}/unexport

if [[ "$count" == "$TARGET_COUNT" ]]; then
   echo -e "${GREEN}[OK] GPIO test passed${RESET}"
else
   echo -e "${RED}[ERROR] GPIO test failed${RESET}"
   echo -e "test procedure interrupted."
   exit
fi


##
## RUN STREAMING TEST
##

APP_FULLPATH=$APPS_PATH/$APP_PATH

# h8 streaming app
if [ $CAMERA_SENSOR_TYPE == "imx219" ]; then
   if [ ! -f "$APP_FULLPATH/"$APP_CHECK ]; then
      echo -e "${YELLOW}[WARNING]$APP_FULLPATH missing, uploading test app.${RESET}"
      cd
      tar -xvf detection_qbastrial_h8.tar >/dev/null 2>&1
   fi
   if [ ! -f "$APP_FULLPATH/"$APP_CHECK ]; then
      echo -e "${RED}[ERROR]$APP_FULLPATH does exist.${RESET}"
      echo -e "test procedure interrupted."
      exit
   fi
else
   # TODO: enable AR0234/AR0822 for ASTRIAL-H8 and imx678 for ASTRAL-H15
   echo -e "${RED}[ERROR] only imx219 sensor camera supported streaming app.${RESET}"
   echo -e "test procedure interrupted."
   exit  
fi

if [ ! -d "$APP_FULLPATH" ]; then
   echo -e "${RED}[ERROR]$APP_FULLPATH does NOT exist.${RESET}"
   echo -e "test procedure interrupted."
   exit
fi

if [ ! -f "$APP_FULLPATH/$APP_CMD" ]; then
   echo -e "${RED}[ERROR]$APP_CMD does NOT exist.${RESET}"
   echo -e "test procedure interrupted."
   exit
fi


##
## SENSOR CHECK : imx219
##
if [ $CAMERA_SENSOR_TYPE == "imx219" ]; then
   echo -e "${WHITE}Testing camera for imx219 sensor${RESET}"

   if [[ -c /dev/video3 ]]; then
      echo -e "${GREEN}[OK] imx219 sensor is enabled.${RESET}"
   else
      echo -e "${YELLOW}[WARNING] missing camera device for imx219, enabling device${RESET}"
      cd /opt/imx8-isp/bin
      ./run.sh -lm -c dual_imx219_1080p60 &

      sleep 5
   fi

   if [[ -c /dev/video3 ]]; then
      echo -e "${GREEN}[OK] imx219 sensor is enabled.${RESET}"
   else
      echo -e "${RED}[ERROR] could not enable imx219 camera${RESET}"
      echo -e "test procedure interrupted."
      exit
   fi

else
   # TODO: enable AR0234/AR0822 for ASTRIAL-H8 and imx678 for ASTRAL-H15   
   echo -e "${RED}[ERROR] only imx219 sensor camera supported for streaming test.${RESET}"
   echo -e "test procedure interrupted."
   exit  
fi



##
## STREAMING:
##

echo -e "${WHITE}Running: $STREAMING_DURATION streaming test ...${RESET}"

if [ $CAMERA_SENSOR_TYPE == "imx219" ]; then
   cd $APP_FULLPATH
   timeout $STREAMING_DURATION ./detection.sh -i /dev/video3 --udpsink 10.0.0.1
fi


##
## CLEANUP & EXIT
##
if [ $CAMERA_SENSOR_TYPE == "imx219" ]; then
   pkill -f dual_imx219_1080p60
   pkill -f isp_media_server
fi


echo -e
echo -e "${WHITE}******************************${RESET}"
echo -e "${WHITE}bye bye.${RESET}"
echo -e "${WHITE}******************************${RESET}"
echo -e


exit


