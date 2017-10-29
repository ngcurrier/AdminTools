#!/bin/python

import os
import glob
import datetime
from datetime import timedelta
from datetime import date

def main():
   
    yesterday = date.today() - timedelta(1)
    yesterday = yesterday.strftime('%Y%m%d')
    
    list = glob.glob('/scrftp/ftp/upload/cam/security_cam'+yesterday+'*')
    list.sort()
    f = open('/scrftp/ftp/upload/cam/list.txt', 'w')
    for i in list:
        f.write(i+"\n")
   
    f.close()
        
    return

if __name__ == "__main__":
    main()
