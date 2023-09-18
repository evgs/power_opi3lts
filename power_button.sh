#!/bin/bash

#CB1 - example PG9 (32) -> GND (30)
#gpiochip=gpiochip0
#pin=201

#OPI3LTS - PL03 (X7-5,6 for panama-pi)
gpiochip=gpiochip0
pin=3

safe_temp=50

#avoid exit if no physical button is connected
if [ `gpioget -B pull-up $gpiochip $pin` -eq 1 ]; then
        >&2 echo "Button should not be pressed so early, potential wiring problem"
        exit 1
fi;
if [ $? -ne 0 ]; then
        >&2 echo "Permission problems, run this script as root user or modify priveleges for run gpioget"
        exit 1
fi;


while :
do
        #button check placeholder
        sleep 0.2
        [ `gpioget -B pull-up $gpiochip $pin` -eq 0 ] && continue

        echo "1. button event"

        # ready to poweroff in klipper shutdown state
        curl -s http://127.0.0.1:7125/printer/objects/query?webhooks | jq -M .result.status.webhooks.state | grep -q shutdown && echo "2. klipper not runnung" && break

        echo "3. klipper is running"

        # prevent poweroff if printing
        curl -s http://127.0.0.1:7125/printer/objects/query?print_stats | jq -M .result.status.print_stats.state | grep -q printing && echo "4. still printing, NOT shutdown" && continue

        echo "5. no printing task"

        #prevent poweroff if hotend is hot
        hotend_temp=`curl -s http://127.0.0.1:7125/printer/objects/query?extruder | jq .result.status.extruder.temperature`
        is_safe=$(echo "$hotend_temp < $safe_temp" | bc -l)
        echo $hotend_temp $is_safe
        [ $is_safe -eq 1 ] && echo "6. safe hotend temp" && break

        #enable poweroff if no moonraker service running
        [ -z $is_safe ] && echo "7. No moonraker service running" && break
done

echo "shutdown now"

sudo poweroff

