#!/bin/bash

USERID=$(id -u)
LOGS_FOLDER="/var/log/shell-roboshop"
SCRIPT_NAME=$(basename "$0" .sh)
LOGS_FILE="$LOGS_FOLDER/$SCRIPT_NAME.log"

R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

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

echo "========== REDIS SETUP STARTED ==========" | tee -a $LOGS_FILE

dnf module disable redis -y &>>$LOGS_FILE
VALIDATE $? "Disabling default Redis module"

dnf module enable redis:7 -y &>>$LOGS_FILE
VALIDATE $? "Enabling Redis 7 module"

dnf install redis -y &>>$LOGS_FILE
VALIDATE $? "Installing Redis"

sed -i 's/^bind 127.0.0.1/bind 0.0.0.0/' /etc/redis/redis.conf
VALIDATE $? "Allowing Redis to listen on all IPs"

sed -i 's/^protected-mode yes/protected-mode no/' /etc/redis/redis.conf
VALIDATE $? "Disabling protected mode"

systemctl enable redis &>>$LOGS_FILE
systemctl start redis &>>$LOGS_FILE
VALIDATE $? "Starting Redis service"

echo -e "$G Redis setup completed successfully $N"
