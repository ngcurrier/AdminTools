#!/bin/bash

BASENAME="security_cam"
DATE=`date --date="1 days ago" +%Y%m%d`
OUTPUT_DIR="/home/nick/security_video/"
OUTPUTFILE=$OUTPUT_DIR$DATE".avi"
FILELIST="@/scrftp/ftp/upload/cam/list.txt"

echo $OUTPUTFILE

#create list of jpg's expicitly
/etc/create_jpg_list.py

echo 'Creating file' $OUTPUTFILE

mencoder mf://$FILELIST -v -mf fps=10 -ovc lavc -lavcopts vcodec=mpeg4:vqscale=2:vhq:v4mv:trell:autoaspect -o $OUTPUTFILE

#change permissions to allow viewing
chown nick $OUTPUTFILE
chgrp nick $OUTPUTFILE

#notify via e-mail video is prepared
echo 'Security video for '$DATE' has finished processing!' | mutt -s "Security_video {$DATE}" nicholas.currier@gmail.com
