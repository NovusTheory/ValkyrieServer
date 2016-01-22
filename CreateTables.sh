#!/bin/bash

GID=$1;
KEY=$2;
TUID=$3;
GNAME=$4;

FILENAME="$GID.sql";

printf "START TRANSACTION;\n" > $FILENAME &&
printf "DROP TABLE IF EXISTS achievements_%s;\n" $GID >> $FILENAME &&
printf "DROP TABLE IF EXISTS meta_%s;\n" $GID >> $FILENAME &&
printf "DROP TABLE IF EXISTS trusted_users_%s;\n" $GID >> $FILENAME &&
printf "DELETE FROM game_ids WHERE gid='%s';\n" $GID >> $FILENAME &&
printf "INSERT INTO game_ids SET gid='%s', cokey=MD5('%s');\n" $GID $KEY >> $FILENAME &&
printf "CREATE TABLE \`achievements_%s\` LIKE achievements_template;\n" $GID >> $FILENAME &&
printf "CREATE TABLE \`meta_%s\` LIKE meta_template;\n" $GID >> $FILENAME &&
printf "CREATE TABLE \`trusted_users_%s\` LIKE trusted_users_template;\n" $GID >> $FILENAME &&
printf "INSERT INTO \`trusted_users_%s\` SET connection_key=MD5('%s'), uid='%d';\n" $GID $KEY $TUID >> $FILENAME &&
printf "INSERT INTO \`meta_%s\` SET \`key\`='usedReward', value=0;\n" $GID >> $FILENAME &&
printf "INSERT INTO \`meta_%s\` SET \`key\`='usedSpace', value=0;\n" $GID >> $FILENAME &&
printf "INSERT INTO \`meta_%s\` SET \`key\`='name', value='%s';\n" $GID "$GNAME" >> $FILENAME &&
printf "COMMIT;" >> $FILENAME;

mysql -u valkyrie -p valkyrie_engine < $FILENAME;
