
#!/bin/bash

#This finds files in /home/ftp/upload named security_cam* of type file
#and deletes them if they are older than the midnight 4 days ago 
#This buffers with some sleep periods to keep from killing the machine
#since this directory is going to be huge

find /scrftp/ftp/upload/cam -name security_cam\* -type f -mtime +8 -daystart | while read -r; do rm "$REPLY"; sleep 0.1; done
