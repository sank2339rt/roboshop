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
CATALOGUE_HOST=localhost
CATALOGUE_PORT=8080

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

echo "========== CART SERVICE SETUP STARTED ==========" | tee -a $LOGS_FILE

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

curl -L -o /tmp/cart.zip https://roboshop-artifacts.s3.amazonaws.com/cart-v3.zip &>>$LOGS_FILE
VALIDATE $? "Downloading cart service code"

cd /app
rm -rf /app/*
unzip /tmp/cart.zip &>>$LOGS_FILE
VALIDATE $? "Extracting cart service"

npm install &>>$LOGS_FILE
VALIDATE $? "Installing dependencies"

cat <<EOF >/etc/systemd/system/cart.service
[Unit]
Description=Cart Service

[Service]
User=roboshop
Environment=REDIS_HOST=$REDIS_HOST
Environment=CATALOGUE_HOST=$CATALOGUE_HOST
Environment=CATALOGUE_PORT=$CATALOGUE_PORT
ExecStart=/bin/node /app/server.js
SyslogIdentifier=cart

[Install]
WantedBy=multi-user.target
EOF

VALIDATE $? "Creating cart systemd service"

systemctl daemon-reload
systemctl enable cart &>>$LOGS_FILE
systemctl start cart &>>$LOGS_FILE
VALIDATE $? "Starting Cart Service"

echo -e "$G Cart service setup completed successfully $N"
