#!/bin/bash

BASENAME="/scrftp/ftp/upload/cam/security_cam"

if [ $# -eq 0 ]
then
    echo 'usage: $0 [ouput_file.avi] {date-yearmonthday24hour(must use leading zeros)}'
    echo 'example: $0 output.avi 2010082619 will produce video for 08/26/2010 at 7:00pm'
elif [ $# -eq 1 ]
then
    echo 'Encoding all files in foler!!!'
    mencoder mf://*.jpg -v -mf fps=10 -ovc lavc -o $1
elif [ $# -eq 2 ]
then
    echo 'Encoding files for date '${2}'!!!'
    AST="*"
    FULLNAME=${BASENAME}${2}${AST}".jpg"
    echo 'Full file name pattern is '$FULLNAME
    mencoder mf://${FULLNAME} -v -mf fps=10 -ovc lavc -o $1
else
    echo 'Too many arguments!!'
fi

