#!/bin/bash

USERID=$(id -u)
LOGS_FOLDER="/var/log/shell-roboshop"
SCRIPT_NAME=$(basename "$0" .sh)
LOGS_FILE="$LOGS_FOLDER/$SCRIPT_NAME.log"

R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

REDIS_HOST=localhost
MONGO_HOST=localhost

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

echo "========== USER SERVICE SETUP STARTED ==========" | tee -a $LOGS_FILE

dnf module disable nodejs -y &>>$LOGS_FILE
VALIDATE $? "Disabling default NodeJS"

dnf module enable nodejs:20 -y &>>$LOGS_FILE
VALIDATE $? "Enabling NodeJS 20"

dnf install nodejs -y &>>$LOGS_FILE
VALIDATE $? "Installing NodeJS"

id roboshop &>>$LOGS_FILE
if [ $? -ne 0 ]; then
    useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop &>>$LOGS_FILE
    VALIDATE $? "Creating roboshop user"
else
    echo -e "Roboshop user already exists ... $Y SKIPPING $N" | tee -a $LOGS_FILE
fi

mkdir -p /app
VALIDATE $? "Creating /app directory"

curl -L -o /tmp/user.zip https://roboshop-artifacts.s3.amazonaws.com/user-v3.zip &>>$LOGS_FILE
VALIDATE $? "Downloading user service code"

cd /app
rm -rf /app/*
unzip /tmp/user.zip &>>$LOGS_FILE
VALIDATE $? "Extracting user service"

npm install &>>$LOGS_FILE
VALIDATE $? "Installing dependencies"

cat <<EOF >/etc/systemd/system/user.service
[Unit]
Description=User Service

[Service]
User=roboshop
Environment=MONGO=true
Environment=REDIS_URL=redis://$REDIS_HOST:6379
Environment=MONGO_URL=mongodb://$MONGO_HOST:27017/users
ExecStart=/bin/node /app/server.js
SyslogIdentifier=user

[Install]
WantedBy=multi-user.target
EOF

VALIDATE $? "Creating user systemd service"

systemctl daemon-reload
systemctl enable user &>>$LOGS_FILE
systemctl start user &>>$LOGS_FILE
VALIDATE $? "Starting User Service"

echo -e "$G User service setup completed successfully $N"
