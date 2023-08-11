#!/bin/bash

password=`zenity --entry --text="Enter password:"`

qpdf --password=$password --decrypt --replace-input $1  >> ~/logs/log.txt
