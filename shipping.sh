#!/bin/bash

USERID=$(id -u)
LOGS_FOLDER="/var/log/shell-roboshop"
SCRIPT_NAME=$(basename "$0" .sh)
LOGS_FILE="$LOGS_FOLDER/$SCRIPT_NAME.log"

R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

CART_HOST=cart.sank2339.online
MYSQL_HOST=mysql.sank2339.online
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

echo "========== SHIPPING SERVICE SETUP STARTED ==========" | tee -a $LOGS_FILE

dnf install maven -y &>>$LOGS_FILE
VALIDATE $? "Installing Maven"

id roboshop &>>$LOGS_FILE
if [ $? -ne 0 ]; then
    useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop &>>$LOGS_FILE
    VALIDATE $? "Creating roboshop user"
fi

mkdir -p /app
VALIDATE $? "Creating /app directory"

curl -L -o /tmp/shipping.zip https://roboshop-artifacts.s3.amazonaws.com/shipping-v3.zip &>>$LOGS_FILE
VALIDATE $? "Downloading shipping service"

cd /app
rm -rf /app/*
unzip /tmp/shipping.zip &>>$LOGS_FILE
VALIDATE $? "Extracting shipping code"

mvn clean package &>>$LOGS_FILE
VALIDATE $? "Building shipping application"

mv target/shipping-1.0.jar shipping.jar
VALIDATE $? "Renaming JAR file"

cat <<EOF >/etc/systemd/system/shipping.service
[Unit]
Description=Shipping Service

[Service]
User=roboshop
Environment=CART_ENDPOINT=$CART_HOST:8080
Environment=DB_HOST=$MYSQL_HOST
ExecStart=/bin/java -jar /app/shipping.jar
SyslogIdentifier=shipping

[Install]
WantedBy=multi-user.target
EOF

VALIDATE $? "Creating shipping systemd service"

systemctl daemon-reload
systemctl enable shipping &>>$LOGS_FILE
systemctl start shipping &>>$LOGS_FILE
VALIDATE $? "Starting Shipping Service"

dnf install mysql -y &>>$LOGS_FILE
VALIDATE $? "Installing MySQL client"

mysql -h $MYSQL_HOST -uroot -p$MYSQL_ROOT_PASSWORD < /app/db/schema.sql &>>$LOGS_FILE
VALIDATE $? "Loading schema"

mysql -h $MYSQL_HOST -uroot -p$MYSQL_ROOT_PASSWORD < /app/db/app-user.sql &>>$LOGS_FILE
VALIDATE $? "Creating app DB user"

mysql -h $MYSQL_HOST -uroot -p$MYSQL_ROOT_PASSWORD < /app/db/master-data.sql &>>$LOGS_FILE
VALIDATE $? "Loading master data"

systemctl restart shipping &>>$LOGS_FILE
VALIDATE $? "Restarting Shipping Service"

echo -e "$G Shipping service setup completed successfully $N"
