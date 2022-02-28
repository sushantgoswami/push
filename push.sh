#!/bin/bash
#       Name:           push.sh
#       Author:         Sushant Goswami
#       Creation:       16-Dec-2021
#       Version:        0.01
#       Purpose:        Push the sudoers file via ssh to all LLY/GUTS hosts
#       Todo:
#       NOTE:           This file generate and use separate files to push the sudoers in parallel
#
# Revision
#=======================================
# 1.
# 2.
#=======================================
######################## Scope ######################
# The script is intended to copy the master sudoers file in the HCS supported Linux servers
# To exclude the servers, use exclude list or manually metion it in the script.
# script is needed to run via cron on specific interval
######################## End Scope ######################

##################### User Defined Variables #########################
export ZONE=ALL
export PRIMARY_EMAIL=Tcs_Platform_Linux@lists.lilly.com
export SECONDARY_EMAIL_1=goswami_sushant@network.lilly.com
export SECONDARY_EMAIL_2=goswami_sushant@network.lilly.com
export SECONDARY_EMAIL_3=goswami_sushant@network.lilly.com
export PRIMARY_EMAIL_ENABLE=1
export SECONDARY_EMAIL_ENABLE_1=1
export SECONDARY_EMAIL_ENABLE_2=0
export SECONDARY_EMAIL_ENABLE_3=0
export EXCLUDE_SERVER="saarthi saarthi-tmp saarthi-dev"
export EXCLUDE_FILE=push.sudoers.exclude
export BASEDIR=/etc/msudoers
export WORKDIR=var
export LOGDIR=log
export TEMPDIR=tmp
export LOGFILE=push_sh_log
export DB_FILE=push.sudoers
export ERROR_FILE=push_errorlog.txt
export SUCCESS_FILE=push_success.txt
export SUMMARY_FILE=push_summary.txt
export EXCLUDE_LOG_FILE=push_exclude.txt
export MULTITHREADS=1
export THREADS=500
##################### End User Defined Variables #########################

############## Pre Fixed Variables ##############################
export CURRENTDATE=`date | awk '{print $3"-"$2"-"$6}'`
export CURRENTTIMESTAMP=`date | awk '{print $4}' | sed '$ s/:/./g'`
export SERVER_NAME=`hostname`
export JUMPSERVER=$SERVER_NAME
export DOMAIN_NAME=am.lilly.com
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
export grabdb=$BASEDIR/$DB_FILE
export errorfile=$BASEDIR/$LOGDIR/$ERROR_FILE
export goodfile=$BASEDIR/$LOGDIR/$SUCCESS_FILE
export excludelogfile=$BASEDIR/$LOGDIR/$EXCLUDE_LOG_FILE
export summaryfile=$BASEDIR/$LOGDIR/$SUMMARY_FILE
export QUEUEDIR=$BASEDIR/$WORKDIR/queue
#################### Do not edit below this line, use variables above ###########################################

###################### Help Menu ##########################################
if [ ! -z $1 ]; then
if [ $1 == "--help" ] || [ $1 == "-h" ]; then
  echo "(MSG 001 HELP): The script is intended to copy the master sudoers file in all the Linux HCS servers"
  echo "(MSG 001 HELP): The exclude list servers can be provided in exlude list or manually mention it in variable."
  echo "(MSG 001 HELP): The script is intended to run through the cron."
  exit 0;
fi
fi
###################### End Help Menu ##########################################

>$errorfile
>$goodfile
>$excludelogfile
>$summaryfile

######### Duplicate instance check #########
DUPLICATE_INSTANCE=2
DUPLICATE_INSTANCE=`ps -ef | grep " push.sh" | grep -v grep | wc -l`
if [ $DUPLICATE_INSTANCE -ge 5 ]; then
 echo "(ERROR:MSG 000): Duplicate instance of push_new.sh found on $SERVER_NAME, .. exiting." | sed -e "s/^/$(date | awk '{print $3"-"$2"-"$6"-"$4}') /" >> $errorfile
 exit 0;
fi
######### End Duplicate instance check #########

if [ ! -z $1 ]; then
if [ $1 == "-host" ]; then
 echo $2 > $BASEDIR/$TEMPDIR/push_host.txt
 grabdb=$BASEDIR/$TEMPDIR/push_host.txt
 export MULTITHREADS=host
fi

if [ $1 == "-inv" ]; then
 grabdb=$2
 export MULTITHREADS=inv
fi
fi

if [ ! -d $BASEDIR/$LOGDIR ]; then
 mkdir $BASEDIR/$LOGDIR
fi

if [ ! -d $BASEDIR/$TEMPDIR ]; then
 mkdir $BASEDIR/$TEMPDIR
fi

if [ $MULTITHREADS == 1 ]; then
if [ ! -d $BASEDIR/$WORKDIR/queue ]; then
 mkdir -p $BASEDIR/$WORKDIR/queue
else
 rm -rf $BASEDIR/$WORKDIR/queue/serverqueue*
 rm -rf $BASEDIR/$WORKDIR/queue/*.lock
fi
split -l $THREADS $grabdb $BASEDIR/$WORKDIR/queue/serverqueue.
fi

###################### start method_01 ######################

method_01()
{

for i in `cat $grabdb`
 do
        NS_FLAG=1
        PING_FLAG=1
        SSH_FLAG=1
        EXCLUDE_FLAG=1

        for j in `echo $EXCLUDE_SERVER`
         do
         EXCLUDE_DETECT=`nslookup $i | grep Name | grep -i $j | wc -l`
          if [ $EXCLUDE_DETECT = 1 ]; then
           echo "(MSG INFO EXCLUDE 01) The host $i is listed as exclude server" | sed -e "s/^/$(date | awk '{print $3"-"$2"-"$6"-"$4}') /" >> $excludelogfile
           EXCLUDE_FLAG=0
           break
          fi
         done

        if [ $EXCLUDE_FLAG == 1 ]; then
        for j in `cat $BASEDIR/$EXCLUDE_FILE`
         do
         EXCLUDE_DETECT=`nslookup $i | grep Name | grep -i $j | wc -l`
          if [ $EXCLUDE_DETECT = 1 ]; then
           echo "(MSG INFO EXCLUDE 01) The host $i is listed as exclude server" | sed -e "s/^/$(date | awk '{print $3"-"$2"-"$6"-"$4}') /" >> $excludelogfile
           EXCLUDE_FLAG=0
           break
          fi
         done
        fi

        if [ $EXCLUDE_FLAG != 0 ]; then
########################## Ping Check ##########################
        NS_CHECK=`nslookup $i | grep Name | wc -l`
        if [ $NS_CHECK != "0" ]; then
          echo "(MSG SUCCESS 02) The host $i is resolving from $JUMPSERVER" | sed -e "s/^/$(date | awk '{print $3"-"$2"-"$6"-"$4}') /" >> $goodfile
          PING_CHECK=`timeout 2s ping -c 1 $i | grep " 0% packet loss" | wc -l`
           if [ $PING_CHECK != "0" ]; then
            echo "(MSG SUCCESS 01) The host $i is pingable from $JUMPSERVER" | sed -e "s/^/$(date | awk '{print $3"-"$2"-"$6"-"$4}') /" >> $goodfile
           else
            echo "(MSG ERROR 01) The host $i is not pingable from $JUMPSERVER" | sed -e "s/^/$(date | awk '{print $3"-"$2"-"$6"-"$4}') /" >> $errorfile
            PING_FLAG=0
           fi
        else
         echo "(MSG ERROR 02) The host $i is not resolving from $JUMPSERVER" | sed -e "s/^/$(date | awk '{print $3"-"$2"-"$6"-"$4}') /" >> $errorfile
        NS_FLAG=0
        PING_FLAG=0
        fi
########################## End Ping Check ##########################

########################## SSH Check ##########################
        if [ $NS_FLAG == 1 ]; then
        SERVER_FQDN=`nslookup $i | grep Name | awk '{print $NF}'`
        BASEHOSTNAME=`echo $i | cut -d "." -f 1`
        SSH_CHECK=`timeout 5s ssh -q -o 'StrictHostKeyChecking=no' $SERVER_FQDN 'uname -a' | grep -i $BASEHOSTNAME | wc -l`
        if [ $SSH_CHECK == "0" ]; then
          echo "(MSG ERROR 03) The host $i is not ssh able from $JUMPSERVER" | sed -e "s/^/$(date | awk '{print $3"-"$2"-"$6"-"$4}') /" >> $errorfile
          SSH_FLAG=0
        else
          echo "(MSG SUCCESS 03) The host $i is ssh able from $JUMPSERVER" | sed -e "s/^/$(date | awk '{print $3"-"$2"-"$6"-"$4}') /" >> $goodfile
        fi
        fi
########################## End SSH Check ##########################

########################## sudoers copy and permmission check ##########################
                if [ $SSH_FLAG == 1 ] && [ $NS_FLAG == 1 ] && [ $EXCLUDE_FLAG == 1 ]; then
                 timeout 8s scp -pq $BASEDIR/sudoers $i:/etc/sudoers > /dev/null 2>&1
                 COPY_SUDO=`echo $?`
                 if [ $COPY_SUDO != "0" ]; then
                  echo "(MSG ERROR 04) Sudo file copied not successfully on host $i" | sed -e "s/^/$(date | awk '{print $3"-"$2"-"$6"-"$4}') /" >> $errorfile
                 else
                  echo "(MSG SUCCESS 04) Sudo file copied successfully on host $i" | sed -e "s/^/$(date | awk '{print $3"-"$2"-"$6"-"$4}') /" >> $goodfile
                 fi
                 timeout 8s ssh -q -o 'StrictHostKeyChecking=no' $i 'chown root:root /etc/sudoers' > /dev/null 2>&1
                 MODE_CHANGE=`echo $?`
                 if [ $MODE_CHANGE != "0" ]; then
                  echo "(MSG ERROR 05) Sudo file mode not changed successfully on host $i" | sed -e "s/^/$(date | awk '{print $3"-"$2"-"$6"-"$4}') /" >> $errorfile
                 else
                  echo "(MSG SUCCESS 05) Sudo file mode change successfully on host $i" | sed -e "s/^/$(date | awk '{print $3"-"$2"-"$6"-"$4}') /" >> $goodfile
                 fi
                fi
########################## End sudoers copy and permmission check ##########################
        fi
 done
}
########################## End method_01 ##########################

########################## export method_01 ##########################

export_method_01()
{
cat << 'EOF' > $BASEDIR/$WORKDIR/queue/multithreads.sh

grabdb=$1

method_01()
{

for i in `cat $grabdb`
 do
        NS_FLAG=1
        PING_FLAG=1
        SSH_FLAG=1
        EXCLUDE_FLAG=1

        for j in `echo $EXCLUDE_SERVER`
         do
         EXCLUDE_DETECT=`nslookup $i | grep Name | grep -i $j | wc -l`
          if [ $EXCLUDE_DETECT = 1 ]; then
           echo "(MSG INFO EXCLUDE 01) The host $i is listed as exclude server" | sed -e "s/^/$(date | awk '{print $3"-"$2"-"$6"-"$4}') /" >> $excludelogfile
           EXCLUDE_FLAG=0
           break
          fi
         done

        for j in `cat $BASEDIR/$EXCLUDE_FILE`
         do
         EXCLUDE_DETECT=`nslookup $i | grep Name | grep -i $j | wc -l`
          if [ $EXCLUDE_DETECT = 1 ]; then
           echo "(MSG INFO EXCLUDE 01) The host $i is listed as exclude server" | sed -e "s/^/$(date | awk '{print $3"-"$2"-"$6"-"$4}') /" >> $excludelogfile
           EXCLUDE_FLAG=0
           break
          fi
         done

        if [ $EXCLUDE_FLAG != 0 ]; then
########################## Ping Check ##########################
        NS_CHECK=`nslookup $i | grep Name | wc -l`
        if [ $NS_CHECK != "0" ]; then
          echo "(MSG SUCCESS 02) The host $i is resolving from $JUMPSERVER" | sed -e "s/^/$(date | awk '{print $3"-"$2"-"$6"-"$4}') /" >> $goodfile
          PING_CHECK=`timeout 2s ping -c 1 $i | grep " 0% packet loss" | wc -l`
           if [ $PING_CHECK != "0" ]; then
            echo "(MSG SUCCESS 01) The host $i is pingable from $JUMPSERVER" | sed -e "s/^/$(date | awk '{print $3"-"$2"-"$6"-"$4}') /" >> $goodfile
           else
            echo "(MSG ERROR 01) The host $i is not pingable from $JUMPSERVER" | sed -e "s/^/$(date | awk '{print $3"-"$2"-"$6"-"$4}') /" >> $errorfile
            PING_FLAG=0
           fi
        else
         echo "(MSG ERROR 02) The host $i is not resolving from $JUMPSERVER" | sed -e "s/^/$(date | awk '{print $3"-"$2"-"$6"-"$4}') /" >> $errorfile
        NS_FLAG=0
        PING_FLAG=0
        fi
########################## End Ping Check ##########################

########################## SSH Check ##########################
        if [ $NS_FLAG == 1 ]; then
        SERVER_FQDN=`nslookup $i | grep Name | awk '{print $NF}'`
        BASEHOSTNAME=`echo $i | cut -d "." -f 1`
        SSH_CHECK=`timeout 5s ssh -q -o 'StrictHostKeyChecking=no' $SERVER_FQDN 'uname -a' | grep -i $BASEHOSTNAME | wc -l`
        if [ $SSH_CHECK == "0" ]; then
          echo "(MSG ERROR 03) The host $i is not ssh able from $JUMPSERVER" | sed -e "s/^/$(date | awk '{print $3"-"$2"-"$6"-"$4}') /" >> $errorfile
          SSH_FLAG=0
        else
          echo "(MSG SUCCESS 03) The host $i is ssh able from $JUMPSERVER" | sed -e "s/^/$(date | awk '{print $3"-"$2"-"$6"-"$4}') /" >> $goodfile
        fi
        fi
########################## End SSH Check ##########################

########################## sudoers copy and permmission check ##########################
                if [ $SSH_FLAG == 1 ] && [ $NS_FLAG == 1 ] && [ $EXCLUDE_FLAG == 1 ]; then
                 timeout 8s scp -pq $BASEDIR/sudoers $i:/etc/sudoers > /dev/null 2>&1
                 COPY_SUDO=`echo $?`
                 if [ $COPY_SUDO != "0" ]; then
                  echo "(MSG ERROR 04) Sudo file copied not successfully on host $i" | sed -e "s/^/$(date | awk '{print $3"-"$2"-"$6"-"$4}') /" >> $errorfile
                 else
                  echo "(MSG SUCCESS 04) Sudo file copied successfully on host $i" | sed -e "s/^/$(date | awk '{print $3"-"$2"-"$6"-"$4}') /" >> $goodfile
                 fi
                 timeout 8s ssh -q -o 'StrictHostKeyChecking=no' $i 'chown root:root /etc/sudoers' > /dev/null 2>&1
                 MODE_CHANGE=`echo $?`
                 if [ $MODE_CHANGE != "0" ]; then
                  echo "(MSG ERROR 05) Sudo file mode not changed successfully on host $i" | sed -e "s/^/$(date | awk '{print $3"-"$2"-"$6"-"$4}') /" >> $errorfile
                 else
                  echo "(MSG SUCCESS 05) Sudo file mode change successfully on host $i" | sed -e "s/^/$(date | awk '{print $3"-"$2"-"$6"-"$4}') /" >> $goodfile
                 fi
                fi
########################## End sudoers copy and permmission check ##########################
        fi
 done
}

method_01

rm -rf $1.lock

EOF

chmod a+x $BASEDIR/$WORKDIR/queue/multithreads.sh

}

########################## End export method_01 ##########################

if [ $MULTITHREADS == 1 ]; then
 export_method_01
 for l in `ls $BASEDIR/$WORKDIR/queue/serverqueue.*`
  do
   $BASEDIR/$WORKDIR/queue/multithreads.sh $l &
   touch $l.lock
   sleep 2
  done
fi

if [ $MULTITHREADS == 0 ]; then
 for l in `ls $BASEDIR/$WORKDIR/queue/serverqueue.*`
  do
   grabdb=$l
   method_01
  done
fi

if [ $MULTITHREADS == "host" ]; then
 method_01
fi

if [ $MULTITHREADS == "inv" ]; then
 method_01
fi

########################## wait till all threads complete ##########################
THREAD_REMAIN=1
while [ $THREAD_REMAIN != 0 ]
 do
  THREAD_REMAIN=`find $BASEDIR/$WORKDIR/queue/ -name "*.lock" | wc -l`
  sleep 2
 done
########################## wait till all threads complete ##########################

########################## Processing summary file ####################################
Total_number_of_server_in_list=`wc -l $BASEDIR/$DB_FILE`
Total_number_of_server_which_are_sshable=`cat $goodfile | grep "MSG SUCCESS 03" | wc -l`
Total_number_of_server_in_which_sudo_file_is_copied=`cat $goodfile | grep "MSG SUCCESS 04" | wc -l`
Total_number_of_server_in_which_sudo_file_mode_is_changed=`cat $goodfile | grep "MSG SUCCESS 05" | wc -l`
echo "Total_number_of_server_in_list=$Total_number_of_server_in_list" > $summaryfile
echo "Total_number_of_server_which_are_sshable=$Total_number_of_server_which_are_sshable" >> $summaryfile
echo "Total_number_of_server_in_which_sudo_file_is_copied=$Total_number_of_server_in_which_sudo_file_is_copied" >> $summaryfile
echo "Total_number_of_server_in_which_sudo_file_mode_is_changed=$Total_number_of_server_in_which_sudo_file_mode_is_changed" >> $summaryfile
########################## Processing summary file ####################################

########################## Sending Emails ##########################
        if [ $PRIMARY_EMAIL_ENABLE == 1 ]; then
         echo "Push_sudo_new reports on $CURRENTDATE" | mailx -s "Push_sudo_new reports on $CURRENTDATE" -r sudo_repoter@saarthi.am.lilly.com -a $goodfile -a $errorfile -a $excludelogfile -a $summaryfile $PRIMARY_EMAIL
        fi

        if [ $SECONDARY_EMAIL_ENABLE_1 == 1 ]; then
         echo "Push_sudo_new reports on $CURRENTDATE" | mailx -s "Push_sudo_new reports on $CURRENTDATE" -r sudo_repoter@saarthi.am.lilly.com -a $goodfile -a $errorfile -a $excludelogfile -a $summaryfile $SECONDARY_EMAIL_1
        fi

        if [ $SECONDARY_EMAIL_ENABLE_2 == 1 ]; then
         echo "Push_sudo_new reports on $CURRENTDATE" | mailx -s "Push_sudo_new reports on $CURRENTDATE" -r sudo_repoter@saarthi.am.lilly.com -a $goodfile -a $errorfile -a $excludelogfile -a $summaryfile $SECONDARY_EMAIL_2
        fi

        if [ $SECONDARY_EMAIL_ENABLE_3 == 1 ]; then
         echo "Push_sudo_new reports on $CURRENTDATE" | mailx -s "Push_sudo_new reports on $CURRENTDATE" -r sudo_repoter@saarthi.am.lilly.com -a $goodfile -a $errorfile -a $excludelogfile -a $summaryfile $SECONDARY_EMAIL_3
        fi
########################## End Sending Emails ##########################
