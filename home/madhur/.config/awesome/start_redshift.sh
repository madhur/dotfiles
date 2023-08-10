#!/bin/sh

run() {
  if pgrep -f redshift ;
  then
    echo "`date` Executing $@\n" >> ~/logs/log.txt
    "$@" >>~/logs/log.txt 2>&1 &
    echo "Return code: $?" >> ~/logs/log.txt
  else
    echo "`date` Not Executing $@\n" >> ~/logs/log.txt
  fi
}


run redshift -l 0:0 -t 4500:4500 -r