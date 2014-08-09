#!/bin/bash

#
# Say (espeak) the sender name if ICY-Name is received
# i.e. "@I ICY-NAME: Bayern 2 Sued"
# for further information (see /tmp/radio/infos.txt)
# the main skript is used for 
# infos coming on pressing keys (i.e. "KPEnter")
#

RADIO_FIFO="/tmp/radio/mpg123"

speak() {
   echo "VOLUME 20" > $RADIO_FIFO
   sleep .5
   ## espeak -s 100 -v de "$SENDERNAME"
   espeak -s 100 -v de "$SENDERNAME" -w sender.wav
   aplay sender.wav
   echo "VOLUME 100" > $RADIO_FIFO
}

while read -ra MPG123_INFO
do 
echo ${MPG123_INFO[*]}
  # info is in array MPG123_INFO
  # 0: "@I"
  # 1: "ICY-NAME:"
  # 2-N: Sender name
  # Extract Sender name
  if [[ "${MPG123_INFO[1]}" == "ICY-NAME:" ]]
  then
    SENDERNAME=${MPG123_INFO[@]:2}
    echo Sendername=$SENDERNAME
    if [ -p $RADIO_FIFO ]
    then
      # espeak gives better performance if
      # mutated vowels are witten natively
      SENDERNAME=${SENDERNAME//ue/ü}
      SENDERNAME=${SENDERNAME//ae/ä}
      SENDERNAME=${SENDERNAME//oe/ö}
      echo $SENDERNAME > /tmp/radio/name.txt
      speak
    fi
  # Write Meta-Data into infos-file
  elif [[ "${MPG123_INFO[1]}" == "ICY-META:" ]]
  then
    echo "Infotext roh: ${MPG123_INFO[*]}"
    INFOTEXT=$(expr "${MPG123_INFO[*]}" : ".*StreamTitle='\(.*\)';")
    echo "Infotext: $INFOTEXT"
    echo "$INFOTEXT" >> /tmp/radio/infos.txt
  fi
done



