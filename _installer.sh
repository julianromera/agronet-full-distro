#!/bin/bash

# must start with '/'
DESTINATION_DIR="/www/agronet_test1"
DATABASE_NAME="agronet_test1"
DATABASE_ADMIN="root"

DRUSH=`which drush`
GIT=`which git` 
MYSQLADMIN=`which mysqladmin`
TAR=`which tar` 

if [ "x$MYSQLADMIN" = "x" ];then
    echo "An MySql Database, and access to mysqladmin command is required."
    exit 1
fi

if [ "x$DRUSH" = "x" ];then
    echo "Drush command not found. Drush version >= 6 is required."
    exit 1
fi

if [ "x$GIT" = "x" ];then
    echo "Git command not found. "
    exit 1
fi

if [ "x$TAR" = "x" ];then
    echo "Tar command not found. "
    exit 1
fi

if [ "x$DESTINATION_DIR" = "x" ];then
    echo "DESTINATION_DIR can not be empty."
fi

if [ -d $DESTINATION_DIR ];then
    echo "Destination directory ($DESTINATION_DIR) should not exist. edit this file to change it."
    exit 1
fi


install() {

    cd /tmp

    if [ -d /tmp$DESTINATION_DIR ];then
      echo -n "/tmp$DESTINATION_DIR exists. Overwrite it? (y/n) "
      read yesno < /dev/tty
      
      if [ "x$yesno" != "x" ] && [ "x$yesno" = "xy" ];then
          rm -rf /tmp$DESTINATION_DIR
      else
          echo "quiting.."
          exit 0
      fi
      
    fi
    
    echo "cloning remote respository.."
    git clone https://github.com/julianromera/agronet.git /tmp$DESTINATION_DIR 

    cd /tmp$DESTINATION_DIR
    ./make-agronet.sh 

    echo "copying recently created dir to destination.."
    mkdir -p $DESTINATION_DIR 
    cp -R /tmp$DESTINATION_DIR/tmp/agronet/* $DESTINATION_DIR 


    echo "copying scripts to $DESTINATION_DIR.."
    
    cp /tmp$DESTINATION_DIR/*.sh $DESTINATION_DIR
    res=$?
    checkok $res
    cp /tmp$DESTINATION_DIR/*.inc $DESTINATION_DIR
    res=$?
    checkok $res

    echo -n 'enter your Drupal MySql user: '
    read my_user < /dev/tty

    echo -n 'enter your Drupal MySql password: '
    read -s my_passwd < /dev/tty
    

    echo "Installing full site.. please be patient"
    cd $DESTINATION_DIR
    
    if [ ! -d $DESTINATION_DIR ];then
      echo "destination directory ($DESTINATION_DIR) doesn't exist (?). aborting.."
      exit 1
    fi
    
    drush -y --root=$DESTINATION_DIR site-install commons --account-name=admin --account-pass=admin --db-url=mysql://`echo $my_user`:`echo $my_passwd`@localhost/$DATABASE_NAME
    res=$?
    checkok $res

    echo "downloading latest database-dump"
    curl --progress-bar -O  https://raw.github.com/julianromera/agronet-database/master/agronet-db.sql.tar
    res=$?    
    checkok $res

    
    if [ ! -f agronet-db.sql.tar ] || [ ! -s agronet-db.sql.tar ];then
       echo "there was an error downloading database. aborting.."
       exit 1
    fi

    cd $DESTINATION_DIR

    echo "Uncompressing database..."
    
    sqlfile=`tar -xvf agronet-db.sql.tar`
    res=$?
    checkok $res

    if [ ! -f $sqlfile ] || [ ! -s $sqlfile ];then
       echo "there was an error downloading database. aborting.."
       exit 1
    fi
    

    echo "Doing modifications to Drupal Commons..."

    cd $DESTINATION_DIR
    ./conf-agronet.sh -x $DESTINATION_DIR $sqlfile 
    res=$?
    checkok $res
    
    echo "postinstalling..."

    cd $DESTINATION_DIR_
    ./postinstall.sh $DESTINATION_DIR
    res=$?
    checkok $res
    
    drush --root=$DESTINATION_DIR cc all
    res=$?
    checkok $res

    #drush --root=$DESTINATION_DIR updb
    #res=$?
    #checkok $res

    echo "Check that $DESTINATION_DIR/sites/default/settings.php contains the same database" 
    echo "credentials than you just created"

    
    
}

checkok() {
    if [ $1 -ne 0 ];then
        echo "Something went wrong. aborting.."
        exit 1
    fi
}


echo "creating database $DATABASE_NAME... enter mysql ADMIN password"

sudo mysqladmin -u$DATABASE_ADMIN -p create $DATABASE_NAME
res=$?

if [ $res -ne 0 ];then
    echo -n 'Something went wrong. continue? (y/n) ' 
    read yesno < /dev/tty
    
    if [ "x$yesno" = "x" ] || [ "x$yesno" != "xy" ];then
      exit 1
    fi
fi



install


