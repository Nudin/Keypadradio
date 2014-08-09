# This file is part of keypadradio
# (C) Oliver Rath, Michael Schönitzer 2013-2014
# 
# This code is under GPLv3
#


display_text() {
  # Display (currently) only supports ASCII
  # remove everything else
  one="$1"
  one="${one//ü/ue}"
  one="${one//ä/ae}"
  one="${one//ö/oe}"
  one=$(echo $one | tr -cd '[:print:]')
  two="$2"
  two="${two//ü/ue}"
  two="${two//ä/ae}"
  two="${two//ö/oe}"
  two=$(echo $two | tr -cd '[:print:]')
  sudo python display.py "$one" "$two"
}
