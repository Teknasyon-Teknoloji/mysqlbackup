Mysql backup script with S3 option.

## Usage

### Requirements

mysqldump must be installed. Script also uses gzip and date commands.

If you want to use S3 backup, aws-cli should be installed and aws credentials must be configured with "aws configure aws configure --profile <PROFILE_NAME>" command.
Please refer to http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-set-up.html

### Basic usage
``` sh
$ ./mysqlbackup.sh -d /mnt/backups localhost mydbname
```

Gzipped backup file will be created at backup dir "/mnt/backups"

### Arguments
./mysqlbackup.sh HOST DB [TABLE]

**HOST**: Mysql hostname. Required.
**DB** : Mysql db name to backup. Required.
**TABLE** :  Just one table from mysql db can be backuped. Optional
 
### Options
**-d <BACKUP_DIR>**: Local backup dir for sql dump file. Required.
**-u <MYSQL_USERNAME>**: Mysql username. If not given, "root" will be used.
**-p <MYSQL_PASSWORD>**: Mysql password. If not given, no password used. If given with empty string, password will be prompted.
**-e <TABLES>**: Table(s) can be excluded from backup. Table names should be given comma-seperated e.g. table1,table2. Optional.
**--s3-bucket <S3_BUCKET_NAME>**: To send backup file to S3 bucket, bucket name should be given. Optional
**--aws-profile <AWS_PROFILE_NAME>**: Profile name for aws config. Required if S3 bucket name given.
**--s3-delete-dest**: If given, S3 sync will used with "--delete" option. Optional. For more info http://docs.aws.amazon.com/cli/latest/reference/s3/sync.html

## Examples

Simple local backup: 

``` sh
$ ./mysqlbackup.sh -u backupuser -p -d /mnt/backups localhost mydbname
```


Local and S3 backup: 

``` sh
$ ./mysqlbackup.sh -u backupuser -p -d /mnt/backups --s3-bucket=mybackupbucket --aws-profile=backupprofile localhost mydbname
```


## Contributing
You can contribute by forking the repo and creating pull requests. You can also create issues or feature requests.

## License
This project is licensed under the MIT license. `LICENSE` file can be found in this repository.