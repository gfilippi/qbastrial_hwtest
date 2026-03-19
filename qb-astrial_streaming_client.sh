#!/bin/bash

PIPELINE='gst-launch-1.0 udpsrc port=5000 caps="application/x-rtp-stream, encoding-name=H264" ! queue ! rtpstreamdepay ! queue ! rtph264depay ! queue ! decodebin ! videoconvert n-threads=8 ! "video/x-raw,height=720,width=1280" ! autovideosink'

trap 'echo; echo "Stopping..."; exit 0' SIGINT

while true; do
    echo "Launching pipeline..."
    # Use timeout to kill pipeline if it runs too long without data
    timeout 10s bash -c "$PIPELINE"

    if [ $? -eq 124 ]; then
        echo "Pipeline timed out (no data). Restarting..."
    else
        echo "Pipeline exited normally. Restarting..."
    fi

    sleep 2
done


