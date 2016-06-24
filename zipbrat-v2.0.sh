#!/bin/bash
# zipBraT -- Tar/Bzip2 Backup Script -- 06/17/2016           #
# Archive/Compress and manage files                          #
# - Create daily file and optional weekly database backups   #
# - Files are archived with tar and compressed with bzip2    #
# - Meant for a Drupal Webserver but can be adapted          #
# If something goes wrong, blame Anthony Powell              #
##############################################################

############# USAGE SCENARIO #########################################
# You are tasked with backing up a linux drupal webserver            #
# - configure Source File Location as Drupal's Source files          #
# - configure Source Database Location as nested website(s) files    #
# - configure the location to store a daily local backup of files    #
# 	as well as a weekly backup of the database Files                 #
# - configure the Server as the address of the SCP server to send    #
# 	backups to as created for another layer of redundancy            #
# - configure the SCP User as the login user of the SCP server       #
# 	In order for this to work you should have configured SSH Key     #
#	Authentication for this user                                     #
# - configure the location to store SCP backups on the remote server #
# - Run the script manually or through a cronjob                     #
######################################################################

## Parameters and Usage #################################################################
## "USAGE: zipbrat.x.x.sh -l [1,0] -s scpServerAddress -u scpUser -n [1,0] -d"          #
##  "-l: Log switch is on by default. If set to 0, it will be disabled."                #
##  "-s: Server selection switch. You can manually enter address here."                 #
##  "-u: Server User switch. You can manually enter the user to log into server."       #
##  "-d: Debug switch is off by default. If applied, it will be Enabled."               #
##  "-n: Networking switch is on by default. If set to 0, SCP will be disabled."        #
#########################################################################################

# CHANGE THE FILE LOCATIONS LISTED IN THE CONSTANTS BELOW   #
# Zipbrat supports backing up of up to two nested locations #
# For example, you can backup a webserver source every day, #
# but only backup its media and large data once a week.     #
# The FILE backups are daily while the DATABASE backups are #
# weekly.                                                   #
# The source and database file locations must omit last /   #
# The backup location must contain the leading /            #
# eg. SOURCE_FILE_LOCATION="~/Documents"                    #
# BACKUP_LOCATION="~/Documents/Backups/"					#
# The SCP_BACKUP_LOCATION starts at root on the remote drive#
# Utilize cygwin or the linux subsystem for windows compat  #

## CONFIGURATION SETTINGS ###################################
SOURCE_FILE_LOCATION=""
SOURCE_DATABASE_LOCATION=""
BACKUP_LOCATION=""
SERVER=""
SCPUSER=""
SCP_BACKUP_LOCATION=""
BACKUP_NAME=$(date +"%m-%d-%y")"-SourceBackup.tar.bz2"
DBACKUP_NAME=$(date +"%m-%d-%y")"-SitesBackup.tar.bz2"
NETWORKING=1

# The integer here determines the day of the week to backup databases
# 1-7 for Mon-Sun
BACKUP_DAY=5

# The integer here determines the number of backups to perform.
# Single or Dual mode represented by 1 or 2
BACKUP_MODE=2

# Don't Change the following constants ###################
# I mean, unless you want to ############################
CLEAN="*SourceBackup.tar.bz2"
COMMON="*Backup.tar.bz2"
START_TIME=$(date +%s)
DATE_CHECK=$(date +%u)
LOG=1
DEBUG=""

#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_#_

## Functions  ##
checkSourceDir () {
	if [ -d "$1" ]; then
		echo "File source location exists -- Moving On"
	else
		echo "Can't find File source! Exiting! :("
		exit 1
	fi
	}

	#Parameters: pass in this order,
	# $1 - BACKUP_LOCATION - the path to where the backup will be stored,
	#				relative to the script's location.
	checkBackupDir () {
	if [ -d "$1" ]; then
		echo "Backup location exists -- Moving On"
	else
		mkdir "$BACKUP_LOCATION" && echo "Backup directory created"
	fi
}

#Parameters: pass in this order,
# $1 - BACKUP_LOCATION - the path to where the backup will be stored,
#				relative to the script's location.
# $2 - BACKUP_NAME - the filename of the backup. This contains the date and time
#				of the archive.
# $3 - SOURCE_FILE_LOCATION - the path to where the files to be backed up are
#				stored.
# $4 - SOURCE_DATABASE_LOCATION - the path to where databases to be backed up are,
#				if this path is left blank it will be skipped. Fill it in to backup Drupal
#				Database as well as its files.
# $5 - BACKUP_DAY - The day that the second backup should be performed. 1-5 for
#				Mon - Fri.
# $6 - BACKUP_MODE - The mode that the script should run in. Single or Dual
#       Backup modes.
archiveTBZ () {
	echo "Starting backup of source files..."
	tar -chjvf $1$2 $3 --exclude=$4 && echo "Done!"
	if [ $6 -eq 2 ] && [ $DATE_CHECK -eq $5 ] || [ $6 -eq 2 ] && [ "$DEBUG" == "DEBUG" ]; then
		if [ -d $4 ]; then
			echo "Starting backup of Sites files..."
			tar -chjvf $1$DBACKUP_NAME $4 && echo "Done!"
		else
			echo "No Sites location specified -- Moving On"
		fi
	fi
}

cleanBackups () {
	echo "Cleaning old backups..."

	#Delete backups older than a day
	find . -name "$CLEAN" -type f -mmin +$((60*24)) -exec rm -f {} \; && echo "Source Clean Done!"

	#Delete backups older than 6 days
	find . -name "$COMMON" -type f -mmin +$((60*144)) -exec rm -f {} \; && echo "Sites Clean Done!"
}

deliverToServer () {
	if [ "$DEBUG" == "" ] && [ $NETWORKING -eq 1 ]; then
		echo "Attempting to scp backups to server..."
		scp -v3 $BACKUP_LOCATION$BACKUP_NAME ${SCPUSER}@${SERVER}:${SCP_BACKUP_LOCATION}${BACKUP_NAME} && echo "Source Backup Success!"

		if [ -f $BACKUP_LOCATION$DBACKUP_NAME ]; then
			scp -v3 $BACKUP_LOCATION$DBACKUP_NAME ${SCPUSER}@${SERVER}:${SCP_BACKUP_LOCATION}$DBACKUPNAME && echo "Sites Backup Success!"
		else
			echo "No sites to back up."
		fi
	fi
}

logGen () {
	if [ "$LOG" -eq "1" ]; then
		echo "Writing log."
		CURRENT_TIME=$(date +"%x %r %Z")
		TIME_STAMP="Backup completed at $CURRENT_TIME on $HOSTNAME by $USER"
		cat <<- MARK > "${BACKUP_LOCATION}log.html" && echo "Log written to log.html"
			<HTML>
			<HEAD>
			<TITLE>$DEBUG -- ZipBraT Backup -- $CURRENT_TIME</TITLE>
			</HEAD>
			<BODY>
			<h2>$TIME_STAMP</h2>
			<br>
			<p>Files in backup directory<p>
			<pre>`ls -l $BACKUP_LOCATION`</pre>
			<br>
			<p>File space remaining on Disk</p>
			<pre>`df -P -h .`</pre>
			<p>Tail Mail</p>
			<pre>`tail $MAIL`</pre>
			</BODY>
			</HTML>
		MARK
	fi
}

paramInit () {
	while getopts ":l:s:dhu:n:" SWITCH; do
		case $SWITCH in
			l)
				LOG="$OPTARG";;
			s)
				SERVER="$OPTARG";;
			u)
				SCPUSER="$OPTARG";;
			n)
				NETWORKING=$OPTARG;;
			d)
				DEBUG="DEBUG"
				echo "DEBUG Mode Triggered!";;
			h)
				echo "USAGE: zipbrat.x.x.sh -l [1,0] -s scpServerAddress -u scpUser -n [1,0] -d"
				echo "-l: Log switch is on by default. If set to 0, it will be disabled."
				echo "-s: Server selection switch. You can manually enter address here."
				echo "-u: Server User switch. You can manually enter the username to log into server."
				echo "-d: Debug switch is off by default. If applied, it will be Enabled."
				echo "-n: Networking switch is on by default. If set to 0, SCP will be disabled."
				echo "Read the script source comments for more details..."
				exit 0;;
			\?)
				echo "Invalid switch: -$OPTARG. Consult -h.";;
			:)
			  echo "Switch -$OPTARG requires an argument. Consult -h."
				exit 1;;
		esac
	done
}

## Main ##
paramInit $@
checkSourceDir $SOURCE_FILE_LOCATION
checkBackupDir $BACKUP_LOCATION
archiveTBZ $BACKUP_LOCATION $BACKUP_NAME $SOURCE_FILE_LOCATION $SOURCE_DATABASE_LOCATION $BACKUP_DAY $BACKUP_MODE
deliverToServer
cleanBackups
logGen

echo "Done."
exit 0
