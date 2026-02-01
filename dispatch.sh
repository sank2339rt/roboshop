#!/bin/bash

USERID=$(id -u)
LOGS_FOLDER="/var/log/shell-roboshop"
SCRIPT_NAME=$(basename "$0" .sh)
LOGS_FILE="$LOGS_FOLDER/$SCRIPT_NAME.log"

R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

RABBITMQ_HOST=localhost
AMQP_USER=roboshop
AMQP_PASS=roboshop123

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

echo "========== DISPATCH SERVICE SETUP STARTED ==========" | tee -a $LOGS_FILE

dnf install golang -y &>>$LOGS_FILE
VALIDATE $? "Installing GoLang"

id roboshop &>>$LOGS_FILE
if [ $? -ne 0 ]; then
    useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop &>>$LOGS_FILE
    VALIDATE $? "Creating roboshop user"
fi

mkdir -p /app
VALIDATE $? "Creating /app directory"

curl -L -o /tmp/dispatch.zip https://roboshop-artifacts.s3.amazonaws.com/dispatch-v3.zip &>>$LOGS_FILE
VALIDATE $? "Downloading dispatch service"

cd /app
rm -rf /app/*
unzip /tmp/dispatch.zip &>>$LOGS_FILE
VALIDATE $? "Extracting dispatch code"

go mod init dispatch &>>$LOGS_FILE
go get &>>$LOGS_FILE
go build &>>$LOGS_FILE
VALIDATE $? "Building dispatch application"

cat <<EOF >/etc/systemd/system/dispatch.service
[Unit]
Description=Dispatch Service

[Service]
User=roboshop
Environment=AMQP_HOST=$RABBITMQ_HOST
Environment=AMQP_USER=$AMQP_USER
Environment=AMQP_PASS=$AMQP_PASS
ExecStart=/app/dispatch
SyslogIdentifier=dispatch

[Install]
WantedBy=multi-user.target
EOF

VALIDATE $? "Creating dispatch systemd service"

systemctl daemon-reload
systemctl enable dispatch &>>$LOGS_FILE
systemctl start dispatch &>>$LOGS_FILE
VALIDATE $? "Starting Dispatch Service"

echo -e "$G Dispatch service setup completed successfully $N"
