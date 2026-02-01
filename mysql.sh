#!/bin/bash

USERID=$(id -u)
LOGS_FOLDER="/var/log/shell-roboshop"
SCRIPT_NAME=$(basename "$0" .sh)
LOGS_FILE="$LOGS_FOLDER/$SCRIPT_NAME.log"

R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

MYSQL_ROOT_PASSWORD="RoboShop@1"

if [ $USERID -ne 0 ]; then
    echo -e "$R Please run this script with root access $N" | tee -a $LOGS_FILE
    exit 1
fi

mkdir -p $LOGS_FOLDER

VALIDATE(){
    if [ $1 -ne 0 ]; then
        echo -e "$2 ... $R FAILURE $N" | tee -a $LOGS_FILE
        exit 1
    else
        echo -e "$2 ... $G SUCCESS $N" | tee -a $LOGS_FILE
    fi
}

echo "========== MYSQL SETUP STARTED ==========" | tee -a $LOGS_FILE

dnf install mysql-server -y &>>$LOGS_FILE
VALIDATE $? "Installing MySQL Server"

systemctl enable mysqld &>>$LOGS_FILE
systemctl start mysqld &>>$LOGS_FILE
VALIDATE $? "Starting MySQL Service"

mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD';" &>>$LOGS_FILE
VALIDATE $? "Setting MySQL root password"

echo -e "$G MySQL setup completed successfully $N"
