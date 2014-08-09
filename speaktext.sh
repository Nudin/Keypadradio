# This file is part of keypadradio
# (C) Oliver Rath, Michael Schönitzer 2013-2014
# 
# This code is under GPLv3
#


# Use espeak_text to read text while setting volume temporarly down
speak_text() {
   SENDERNAME="${*}"
   # espeak_text gives better performance if
   # mutated vowels are witten natively
   SENDERNAME="${SENDERNAME//ue/ü}"
   SENDERNAME="${SENDERNAME//ae/ä}"
   SENDERNAME="${SENDERNAME//oe/ö}"
   echo "VOLUME 20" > $RADIO_FIFO
   sleep .5
   espeak_text -s 100 -v de "$SENDERNAME" -w sender.wav
   aplay sender.wav
   rm sender.wav
   echo "VOLUME $volume" > $RADIO_FIFO
}
