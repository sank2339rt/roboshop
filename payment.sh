#!/bin/bash

USERID=$(id -u)
LOGS_FOLDER="/var/log/shell-roboshop"
SCRIPT_NAME=$(basename "$0" .sh)
LOGS_FILE="$LOGS_FOLDER/$SCRIPT_NAME.log"

R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

CART_HOST=localhost
USER_HOST=localhost
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

echo "========== PAYMENT SERVICE SETUP STARTED ==========" | tee -a $LOGS_FILE

dnf install python3 gcc python3-devel -y &>>$LOGS_FILE
VALIDATE $? "Installing Python dependencies"

id roboshop &>>$LOGS_FILE
if [ $? -ne 0 ]; then
    useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop &>>$LOGS_FILE
    VALIDATE $? "Creating roboshop user"
fi

mkdir -p /app
VALIDATE $? "Creating /app directory"

curl -L -o /tmp/payment.zip https://roboshop-artifacts.s3.amazonaws.com/payment-v3.zip &>>$LOGS_FILE
VALIDATE $? "Downloading payment service"

cd /app
rm -rf /app/*
unzip /tmp/payment.zip &>>$LOGS_FILE
VALIDATE $? "Extracting payment code"

pip3 install -r requirements.txt &>>$LOGS_FILE
VALIDATE $? "Installing Python dependencies"

cat <<EOF >/etc/systemd/system/payment.service
[Unit]
Description=Payment Service

[Service]
User=root
WorkingDirectory=/app
Environment=CART_HOST=$CART_HOST
Environment=CART_PORT=8080
Environment=USER_HOST=$USER_HOST
Environment=USER_PORT=8080
Environment=AMQP_HOST=$RABBITMQ_HOST
Environment=AMQP_USER=$AMQP_USER
Environment=AMQP_PASS=$AMQP_PASS
ExecStart=/usr/local/bin/uwsgi --ini payment.ini
ExecStop=/bin/kill -9 \$MAINPID
SyslogIdentifier=payment

[Install]
WantedBy=multi-user.target
EOF

VALIDATE $? "Creating payment systemd service"

systemctl daemon-reload
systemctl enable payment &>>$LOGS_FILE
systemctl start payment &>>$LOGS_FILE
VALIDATE $? "Starting Payment Service"

echo -e "$G Payment service setup completed successfully $N"
