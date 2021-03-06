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
rm -rf  /dev/shm/keypadradio
log "Creating /dev/shm/keypadradio if not exist ..."
mkdir -p /dev/shm/keypadradio
KEYPAD_FIFO="/dev/shm/keypadradio/keypad"
RADIO_FIFO="/dev/shm/keypadradio/mpg123"
INPUT_FILE="/dev/shm/keypadradio/input"
NAME_FILE="/dev/shm/keypadradio/name.txt"
INFO_FILE="/dev/shm/keypadradio/infos.txt"
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
      echo $SENDERNAME > $NAME_FILE
      [[ "$speak" == "True" ]] && speak_text "$SENDERNAME"
      [[ "$display" == "True" ]] && display_text "$SENDERNAME" "Volume: $volume"
    fi
  # Extract Meta-Data & write them into infos-file
  elif [[ "${MPG123_INFO[1]}" == "ICY-META:" ]]
  then
    log "Infotext roh: ${MPG123_INFO[*]}"
    INFOTEXT=$(expr "${MPG123_INFO[*]}" : ".*StreamTitle='\(.*\)';")
    log "Infotext: $INFOTEXT"
    echo "$INFOTEXT" >> $INFO_FILE
  fi
done
}


# Start player (mpg123) in background, listening for commands on fifo
log "starting mpg123 with fifo ..."
(mpg123 -q \
       -R \
       -o alsa \
       --fifo $RADIO_FIFO | grep -v --line-buffered "@F" | parseoutput) &

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
echo "VOLUME $volume" > $RADIO_FIFO

# Parse given userinput
parseinput() {
  input=$(cat $INPUT_FILE | tr -d [:space:] | sed 's/\([0-9]\)KP/\1/g')
  # Keys 0-9: change to corresponding channel
  if [[ $input == KP[0-9]* ]]
  then
    echo Senderwechsel
    # delete infos, if sender changes
    rm $INFO_FILE
    # Extract number
    DIGIT=${input:2}
    log "switching to Sender $DIGIT"
    echo "LOADLIST 1 ${SENDER[$DIGIT]}" > $RADIO_FIFO
  # Key '-': decrease Volume
  elif [[ $input == KPMinus ]]
  then
    ((volume-=10))
    echo "VOLUME $volume" > $RADIO_FIFO
    [[ "$display" == "True" ]] && display_text "$(tail -n 2 $NAME_FILE)" "Volume: $volume"
  # Key '+': increase volume
  elif [[ $input == KPPlus ]]
  then
    ((volume+=10))
    echo "VOLUME $volume" > $RADIO_FIFO
    [[ "$display" == "True" ]] && display_text "$(tail -n 2 $NAME_FILE)" "Volume: $volume"
  # Key 'Dot': exit (& shutdown)
  elif [[ $input == KPDot ]]
  then
    sudo killall keypad-decoder
    killall mpg123
    #sudo halt
  # Key 'Enter': Say info text
  elif [[ $input == KPEnter ]]
  then
    # tell uniq lines in infos.txt
    [[ "$speak" == "True" ]] && \
        speak_text "$(tac $INFO_FILE | awk '!seen[$0]++' | tac )"
    [[ "$display" == "True" ]] && \
        display_text "$(tac $INFO_FILE | awk '!seen[$0]++' | tac )" \
        && sleep 10 && display_text "$(tail -n 1 $NAME_FILE)" "Volume: $volume"
  fi
  echo > $INPUT_FILE
}

# the input loop:
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
  if [[ ${KEYPAD[1]} == KP[0-9] ]] ; then
    bgjob=$(jobs | grep parseinput | cut -d[ -f2 | cut -d] -f1)
    if [[ "$bgjob" != "" ]] ; then
      kill %$bgjob
    fi
    echo -n ${KEYPAD[1]} >> $INPUT_FILE
    (sleep 1; parseinput ) & 
  else
    echo other
    sleep 1
    echo -n ${KEYPAD[1]} > $INPUT_FILE
    parseinput
  fi
  fi
done < $KEYPAD_FIFO
echo ende
