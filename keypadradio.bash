#!/bin/bash
# Switching radio-channels via keypad
# (C) Oliver Rath, 2013-2014
# (C) Michael Schönitzer, 2014
# 
# This code is under GPLv3
#

# load settings-file
. settings

# load display-function for Hitachi HD44780-Display
. displaytext.sh

# load speak-function
. speaktext.sh

# function for colored logs
log() { echo -e '\e[31m'"$*"'\e[0m'; }

# Clean up and initialize
log "Killing running mpg123 and evtest-new processes ..."
sudo killall -9 keypad-decoder
killall -9 mpg123
rm -rf  /tmp/radio
log "Creating /tmp/radio/ if not exist ..."
mkdir -p /tmp/radio
KEYPAD_FIFO="/tmp/radio/keypad"
RADIO_FIFO="/tmp/radio/mpg123"
mkfifo $KEYPAD_FIFO


# Parse the output of mpg123 and extract sender name and Matadata,
# as well as the volume
parseoutput() {
while read -ra MPG123_INFO
do 
echo ${MPG123_INFO[*]}
  # Extract current volume
  if [[ "${MPG123_INFO[0]}" == "@V" ]]
  then
    volume=${MPG123_INFO[1]/.*/}
  # Extract Sender name
  # 0: "@I"
  # 1: "ICY-NAME:"
  # 2-N: Sender name
  elif [[ "${MPG123_INFO[1]}" == "ICY-NAME:" ]]
  then
    SENDERNAME=${MPG123_INFO[@]:2}
    echo Sendername=$SENDERNAME
    if [ -p $RADIO_FIFO ]
    then
      echo $SENDERNAME > /tmp/radio/name.txt
      [[ "$speak" == "True" ]] && speak_text "$SENDERNAME"
      [[ "$display" == "True" ]] && display_text "$SENDERNAME" "Volume: $volume"
    fi
  # Extract Meta-Data & write them into infos-file
  elif [[ "${MPG123_INFO[1]}" == "ICY-META:" ]]
  then
    log "Infotext roh: ${MPG123_INFO[*]}"
    INFOTEXT=$(expr "${MPG123_INFO[*]}" : ".*StreamTitle='\(.*\)';")
    log "Infotext: $INFOTEXT"
    echo "$INFOTEXT" >> /tmp/radio/infos.txt
  fi
done
}


# Start player (mpg123) in background, listening for commands on fifo
log "starting mpg123 with fifo ..."
(mpg123 -q \
       -R \
       -o alsa \
       --fifo /tmp/radio/mpg123 | grep -v --line-buffered "@F" | parseoutput) &

# mpg123 takes a while until the pipe is created
while [ ! -p $RADIO_FIFO ]
do
  log "No fifo found. Waiting one more second ..."
  sleep 1
done

log "fifo does exist now ... "
log "Starting sender ${SENDER[$SENDER_ON_START]} on start ... "
# m3u is a text list of urls sending mp3-stream
# we take just the 1st entry
echo "LOADLIST 1 ${SENDER[$SENDER_ON_START]}" > $RADIO_FIFO

log "Starting keypad decoder ... "
echo sudo ./keypad-decoder $KEYPAD_URL \> $KEYPAD_FIFO
if [ -p $KEYPAD_FIFO ]
then
  log "starting keypad input to keypad fifo ..."
  sudo ./keypad-decoder "$KEYPAD_URL" > $KEYPAD_FIFO &
  # TODO: keypad-decoder has to run as root, because the input
  #       device (/dev/input/by-path/...) is only accessible by
  #       root. Maybe modifying some udev-rule will help...
else
  log "fifo doesnt exist, exiting"
  exit 1 
fi

# set default volume
echo "VOLUME $volume" > /tmp/radio/mpg123

parseinput() {
input=$(cat /dev/shm/radio-input)
# Keys 0-9: change to corresponding channel
    if [[ $input == KP[0-9] ]]
    then
      # delete infos, if sender changes
      rm /tmp/radio/infos.txt
      # on keypad, all key-infos starts with "KP", 
      # i.e. KP1, KPEnter etc.
      # here only KP1..KP9 is for interest
      # so we cut the first two (0 and 1) chars to
      # get the number
      # TODO: Enhance mechanism for entering multiple
      #       digts (i.e. 0-999) for multiple
      #       sender-lists
      DIGIT=${KEYPAD[1]:2}
      log "switching to Sender $DIGIT"
      echo "LOADLIST 1 ${SENDER[$DIGIT]}" > $RADIO_FIFO
    # Key '-': decrease Volume
    elif [[ $input == KPMinus ]]
    then
      ((volume-=10))
      echo "VOLUME $volume" > /tmp/radio/mpg123
      [[ "$display" == "True" ]] && display_text "$(tail -n 2 /tmp/radio/name.txt)" "Volume: $volume"
    # Key '+': increase volume
    elif [[ $input == KPPlus ]]
    then
      ((volume+=10))
      echo "VOLUME $volume" > /tmp/radio/mpg123 
      [[ "$display" == "True" ]] && display_text "$(tail -n 2 /tmp/radio/name.txt)" "Volume: $volume"
    # Key 'Dot': exit (& shutdown)
    elif [[ $input == KPDot ]]
    then
      sudo killall keypad-decoder
      killall mpg123
      break
      #sudo halt
    # Key 'Enter': Say info text
    elif [[ $input == KPEnter ]]
    then
      # tell uniq lines in infos.txt
      [[ "$speak" == "True" ]] && speak_text "$(tac /tmp/radio/infos.txt | awk '!seen[$0]++' | tac )"
      [[ "$display" == "True" ]] && display_text "$(tac /tmp/radio/infos.txt | awk '!seen[$0]++' | tac )" \
      		&& sleep 10 && display_text "$(tail -n 1 /tmp/radio/name.txt)" "Volume: $volume"
    fi
echo > /dev/shm/radio-input
}

# the main loop:
# "read -ra" creates the array (-a option) KEYPAD and reads the
# input of keypad-pipe with "\" used as standard char (-r option)
# IFS="-" sets "-" as delimiter for array-distribution.
# In a while-loop this is set only locally
while IFS="-" read -ra KEYPAD
do
echo ${KEYPAD[*]}
  if [[ "${KEYPAD[0]}" == "Key" ]] && [[ "${KEYPAD[2]}" != "stop" ]]
  then
	echo ${KEYPAD[1]}
	if [[ ${KEYPAD[1]} == [0-9] ]] ; then
		kill %$(jobs | grep parseinput | cut -d[ -f2 | cut -d] -f1) 2>/dev/null 1>&2
		echo -n ${KEYPAD[1]} >> /dev/shm/radio-input
		(sleep 1; parseinput ) & 
	else
		sleep 1
		echo -n ${KEYPAD[1]} > /dev/shm/radio-input
		parseinput
	fi
  fi
done < $KEYPAD_FIFO

