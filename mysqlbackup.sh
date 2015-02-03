#!/bin/sh

usage(){
    echo "Usage : $0 [OPTIONS] HOST DB [TABLE]"
	echo "Options :"
	echo "-u <MYSQL_USERNAME>: Mysql username. If not given, default \"root\" used."
	echo "-p <MYSQL_PASSWORD>: Mysql password. If only \"-p\" used, password will be asked."
	echo "-e <TABLES>: exclude tables(s) ( table names are comma-seperated)"
	echo "-d <BACKUP_DIR>: backup dir for sql file."
	echo "--aws-profile <AWS_PROFILE_NAME>: AWS S3 Bucket Name"
	echo "--s3-bucket <S3_BUCKET>: AWS S3 Bucket Name"
	echo "--s3-delete-dest: If given, files exist in the destination but not in the source will be deleted"
    exit 0
}

if [ $# -eq 0 ]; then usage; fi

MYSQL_DUMP_CMD=`which mysqldump`
if [ ! -x "$MYSQL_DUMP_CMD" ]
then
    echo "mysqldump cmd not found!"
    exit 1
fi

TODAY=`date +%Y.%m.%d_%H%M`
OPT_SPECS=":hpu:e:d:b:-:"
MYSQL_USERNAME="root"
MYSQL_PASSWORD=""
MYSQL_PASSWORD_OPTION=""
MYSQL_HOST="localhost"
BACKUP_DIR=""
DB_NAME=""
TABLE_NAME=""
EXCLUDED_TABLES=""
BACKUP_FILENAME_POSTFIX=""
EXCLUDED_TABLES_OPTION=""

AWS_PROFILE_NAME=""
AWS_S3_BUCKET_NAME=""
AWS_S3_SYNC_DELETE_OPTION=""

while getopts "$OPT_SPECS" optname
do
  case ${optname} in
    h) usage;;
    u) MYSQL_USERNAME="$OPTARG";;
    p)
        MYSQL_PASSWORD="$OPTARG"
        MYSQL_PASSWORD_OPTION="-p$MYSQL_PASSWORD"
        ;;
    e) EXCLUDED_TABLES="$OPTARG";;
    d) BACKUP_DIR="$OPTARG";;
    -)
            case "${OPTARG}" in
                help) usage;;
                s3-delete-dest)
                    AWS_S3_SYNC_DELETE_OPTION="--delete"
                    ;;
                s3-delete-dest=*)
                    AWS_S3_SYNC_DELETE_OPTION="--delete"
                    ;;
                s3-bucket)
                    AWS_S3_BUCKET_NAME="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                    ;;
                s3-bucket=*)
                    AWS_S3_BUCKET_NAME=${OPTARG#*=}
                    ;;
                aws-profile)
                    AWS_PROFILE_NAME="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                    ;;
                aws-profile=*)
                    AWS_PROFILE_NAME=${OPTARG#*=}
                    ;;
                *)
                    usage
                    ;;
            esac;;
    *) ;;   # Default.
  esac
done
shift $(($OPTIND - 1))

if [ ! -d "$BACKUP_DIR" ]
then
    echo "Backup dir \"$BACKUP_DIR\" not found!"
    exit 1
fi
if [ ! -w "$BACKUP_DIR" ]
then
    echo "$BACKUP_DIR is not writable!"
    exit 1
fi

MYSQL_HOST="$1"
if [ -z  ${MYSQL_HOST} ]
then
	echo "Mysql Host arg not found!"
	exit 1
fi

DB_NAME="$2"
if [ -z  ${DB_NAME} ]
then
	echo "Mysql DB Name arg not found!"
	exit 1
fi


if [ "$3" != "" ]
then
    TABLE_NAME="$3"
	BACKUP_FILENAME_POSTFIX=".$TABLE_NAME"
fi

if [ "$EXCLUDED_TABLES" != "" ]
then
	if [ "$TABLE_NAME" != "" ]
	then
		echo "Table name given, excluded table option ignored..."
		EXCLUDED_TABLES=""
	else
		BACKUP_FILENAME_POSTFIX="$BACKUP_FILENAME_POSTFIX-[$EXCLUDED_TABLES]"
		EXCLUDED_TABLES_OPTION=`echo "$EXCLUDED_TABLES" | sed s/,/\ \-\-ignore\-table\=${DB_NAME}./g`
		EXCLUDED_TABLES_OPTION=" --ignore-table=$DB_NAME.$EXCLUDED_TABLES_OPTION"
	fi
fi

if [ "$MYSQL_PASSWORD_OPTION" = "-p" ]
then
    read -s -p "Mysql Password: " MYSQL_PASSWORD
    MYSQL_PASSWORD_OPTION="-p$MYSQL_PASSWORD"
fi

BACKUP_FILENAME="$BACKUP_DIR/$MYSQL_HOST.$DB_NAME${BACKUP_FILENAME_POSTFIX}.$TODAY.sql.gz"

${MYSQL_DUMP_CMD} --single-transaction -q  -c -h ${MYSQL_HOST} -u ${MYSQL_USERNAME} ${MYSQL_PASSWORD_OPTION} ${EXCLUDED_TABLES_OPTION} ${DB_NAME} ${TABLE_NAME} | gzip > ${BACKUP_FILENAME}

if [ $? = 0 ]
then
        if [ ! -f ${BACKUP_FILENAME} ]
        then
				echo "ERROR: Backup file not found: ${BACKUP_FILENAME}"
                exit 1
        fi

        if [ "$AWS_S3_BUCKET_NAME" != "" ]
        then
            AWS_CMD=`which aws`
            if [ ! -x "$AWS_CMD" ]
            then
                echo "aws cmd not found! AWS S3 ignored!"
                exit 1
            fi
            if [ -z  ${AWS_PROFILE_NAME} ]
            then
                echo "Aws profile name required! Please set your aws credentials with cmd \"aws configure\""
                exit 1
            fi
            ${AWS_CMD} configure list --profile ${AWS_PROFILE_NAME} > /dev/null 2>&1
            if [ $? != 0 ]
            then
                echo "Aws profile name failed! Please check your aws configuration with cmd \"aws configure\""
                exit 1
            fi
            ${AWS_CMD} s3 sync ${BACKUP_DIR} s3://${AWS_S3_BUCKET_NAME} ${AWS_S3_SYNC_DELETE_OPTION} --profile ${AWS_PROFILE_NAME}
        fi
else
        echo "ERROR: Mysqldump cmd failed! Exit code: $?"
        exit 1
fi
