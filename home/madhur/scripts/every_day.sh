#!/bin/bash
python /home/madhur/scripts/delete_old_screenshots.py /home/madhur/Screenshots/Timeline
/usr/bin/paccache -r -k 3
#find /home/madhur/.cache/ -type f -atime +30 -print -delete
#docker system prune -af --volumes
