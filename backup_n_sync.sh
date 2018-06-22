#!/bin/bash

UNAME=`whoami`
if [[ "$UNAME" == "root" ]]; then exit; fi

SERVER_NAME="hssrv2"
HS_PERSONAL_PATH="/hs/userm/"$UNAME"/"
HS_PERSONAL_CURRENT="current"
HS_PERSONAL_STABLE="stable"

LOCAL_PATH="/scratch1/"$UNAME"/data2backup/"
LOCAL_CURRENT="current"
LOCAL_STABLE="stable"

LOGFILE=$LOCAL_PATH"backup_n_sync_"`date +%Y-%m-%d_%H-%M-%S`".log"




# CREATE NEEDED DIRECTORIES
(
echo "#######################################"
echo -e "\nCREATE NEEDED DIRECTORIES LOCALLY AND ON TAPE SERVER IF NOT EXISTING:"
if [[ ! -d "$HS_PERSONAL_PATH/$HS_PERSONAL_CURRENT" ]]; then
	ssh $SERVER_NAME mkdir -p $HS_PERSONAL_PATH/$HS_PERSONAL_CURRENT;
	echo "Created directory "$HS_PERSONAL_PATH"/"$HS_PERSONAL_CURRENT
fi
if [[ ! -d "$HS_PERSONAL_PATH/$HS_PERSONAL_STABLE" ]]; then
	ssh $SERVER_NAME mkdir -p $HS_PERSONAL_PATH/$HS_PERSONAL_STABLE;
	echo "Created directory "$HS_PERSONAL_PATH"/"$HS_PERSONAL_STABLE
fi
if [[ ! -d "$LOCAL_PATH/$LOCAL_CURRENT" ]]; then
	mkdir -p $LOCAL_PATH/$LOCAL_CURRENT;
	echo "Created directory "$LOCAL_PATH"/"$LOCAL_CURRENT
fi
if [[ ! -d "$LOCAL_PATH/$LOCAL_STABLE" ]]; then
	mkdir -p $LOCAL_PATH/$LOCAL_STABLE;
	echo "Created directory "$LOCAL_PATH"/"$LOCAL_STABLE
fi
) > $LOGFILE 2>&1


#BACKUP STABLE PROJECTS
(
echo "#######################################"
echo -e "\nBACKUP STABLE PROJECTS NOW:"
cd $LOCAL_PATH/$LOCAL_STABLE;
for i in *; do
	if [[ -L "$i" ]]; then
      project_name=`readlink $i | awk '{gsub("/$","");print}' | awk -F"/" '{print $(NF)}'` ;
      path_2_project=`readlink $i | awk '{gsub("/$","");print}' | awk -F"/" '{gsub($(NF),""); print}'`;
		echo -e "\nProject " $project_name" in "$path_2_project"\n";
		tar_name=$project_name"_"`date +%Y-%m-%d_%H-%M-%S`".tar"
		tar -p --acls -c -v -f $tar_name -C $path_2_project $project_name;
		rsync -e ssh -P -v $tar_name $SERVER_NAME:$HS_PERSONAL_PATH/$HS_PERSONAL_STABLE && \
		rm -f $i $tar_name && echo "stable project "$project_name"in directory "$path_2_project\
		" successfully backupped as "$tar_name" in "$SERVER_NAME:$HS_PERSONAL_PATH/$HS_PERSONAL_STABLE
		ssh $SERVER_NAME release $HS_PERSONAL_PATH/$HS_PERSONAL_STABLE/$tar_name
	fi;
done
) >> $LOGFILE 2>&1
#release after transfer?


#SYNCHRONIZE ONGOING/CURRENT PROJECTS
(
echo "#######################################"
echo -e "\nSYNCHRONIZE ONGOING PROJECTS NOW:"
cd $LOCAL_PATH/$LOCAL_CURRENT;
# <one-way> synchronization
for i in *; do
   if [[ -L "$i" ]]; then
      project_name=`readlink $i | awk '{gsub("/$","");print}' | awk -F"/" '{print $(NF)}'` ;
      path_2_project=`readlink $i | awk '{gsub("/$","");print}' | awk -F"/" '{gsub($(NF),""); print}'`;
		echo -e "\nProject " $project_name" in "$path_2_project"\n";
		rsync -e ssh -v -l -u -P -r $path_2_project/$project_name $SERVER_NAME:$HS_PERSONAL_PATH/$HS_PERSONAL_CURRENT && \
		echo "Ongoing project "$project_name" in directory "$path_2_project\
		" successfully synchronized with "$SERVER_NAME:$HS_PERSONAL_PATH/$HS_PERSONAL_CURRENT/$project_name
	fi;
done
) >> $LOGFILE 2>&1

#REMOVE UNLINKED CURRENT PROJECTS FROM TAPES
(
echo "#######################################"
echo -e "\nREMOVE UNLINKED ONGOING PROJECTS FROM TAPE NOW:"
cd $LOCAL_PATH/$LOCAL_CURRENT;
#removal of remote sync dirs (from hssrv2) if project link has been removed from local <current> dir
for i in $HS_PERSONAL_PATH/$HS_PERSONAL_CURRENT/*; do
	if [[ ! -e `basename $i` ]] && [[ -d "$i" ]]; then
		echo "You unlinked project "`basename $i`" from local current project directory. Remove this project from ongoing project area on tape server as well."
		ssh hssrv2 rm -r $i;
	fi
done
) >> $LOGFILE 2>&1

