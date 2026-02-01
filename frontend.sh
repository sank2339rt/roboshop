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

echo "========== FRONTEND SETUP STARTED ==========" | tee -a $LOGS_FILE

dnf module disable nginx -y &>>$LOGS_FILE
VALIDATE $? "Disabling default Nginx"

dnf module enable nginx:1.24 -y &>>$LOGS_FILE
VALIDATE $? "Enabling Nginx 1.24"

dnf install nginx -y &>>$LOGS_FILE
VALIDATE $? "Installing Nginx"

systemctl enable nginx &>>$LOGS_FILE
systemctl start nginx &>>$LOGS_FILE
VALIDATE $? "Starting Nginx"

rm -rf /usr/share/nginx/html/* &>>$LOGS_FILE
VALIDATE $? "Removing default website content"

curl -o /tmp/frontend.zip https://roboshop-artifacts.s3.amazonaws.com/frontend-v3.zip &>>$LOGS_FILE
VALIDATE $? "Downloading frontend code"

cd /usr/share/nginx/html
VALIDATE $? "Navigating to web root"

unzip /tmp/frontend.zip &>>$LOGS_FILE
VALIDATE $? "Extracting frontend files"

cat <<EOF >/etc/nginx/default.d/roboshop.conf
proxy_http_version 1.1;

location /api/catalogue/ {
    proxy_pass http://localhost:8080/;
}

location /health {
    stub_status on;
    access_log off;
}
EOF

VALIDATE $? "Configuring Nginx reverse proxy"

systemctl restart nginx &>>$LOGS_FILE
VALIDATE $? "Restarting Nginx"

echo -e "$G Frontend setup completed successfully $N"
