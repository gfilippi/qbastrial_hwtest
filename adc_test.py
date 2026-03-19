import time
import argparse
from smbus2 import SMBus

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


# ----------------------------
# Configuration
# ----------------------------
I2C_BUS = 4          # I2C5 usually maps to /dev/i2c-4
ADC_ADDR = 0x48      # MCP3221A0T
POT_ADDR = 0x2e      # MCP4531T (check with i2cdetect)
VREF = 3.3

ADC_MAX = 4095       # 12-bit
POT_MAX = 127        # 7-bit


# ----------------------------
# Functions
# ----------------------------

def set_pot(percent, args):
    """Set MCP4531 wiper position (0–100%)"""
    value = int((percent / 100.0) * POT_MAX)

    with SMBus(I2C_BUS) as bus:
        bus.write_byte_data(POT_ADDR, 0x00, value)

    if args.verbose:
       print(f"Potentiometer set to {percent}% (raw={value})")


def read_adc():
    """Read MCP3221 12-bit ADC"""
    with SMBus(I2C_BUS) as bus:
        data = bus.read_i2c_block_data(ADC_ADDR, 0x00, 2)

    raw = ((data[0] << 8) | data[1]) & 0x0FFF
    voltage = (raw / ADC_MAX) * VREF

    return raw, voltage


def measure( args ):
    raw, voltage = read_adc()
    if args.verbose:
       print(f"ADC Raw (0–4095): {raw}")
       print(f"Voltage (0–3.3V): {voltage:.4f} V")
       print("-" * 40)
    return raw, voltage

# ----------------------------
# Main Sequence
# ----------------------------

def main():
    parser = argparse.ArgumentParser(description="Example script with verbose option")

    # Add verbose flag
    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Enable verbose output"
    )

    args = parser.parse_args()

    # 1) Set to 0%
    set_pot(0, args)
    time.sleep(0.2)
    raw0, voltage0 = measure( args )

    # 2) Set to 100%
    set_pot(100, args)
    time.sleep(0.2)
    raw100, voltage100 = measure( args )

    # 3) Set to 50% 
    set_pot(50, args)
    time.sleep(0.2)
    raw501, voltage501 = measure( args )

    # 3) Set to 50% again (as requested)
    set_pot(50, args)
    time.sleep(0.2)
    raw502, voltage502 = measure( args )

    #
    # SANITY CHECK on I2C functionality
    #

    rv = 0

    if(raw0 > 3500):
       if(raw100 < 450):
          if( (raw501 > 2000) and (raw501<2200)) :
             if( (raw502 > 2000) and (raw502<2200)) :
                rv = 1


    if args.verbose:
       if(rv==1):
          print("[OK] I2C test passed.")
       else:    
          print("[ERROR] I2C test failed.")

    print( rv)

if __name__ == "__main__":
    main()



