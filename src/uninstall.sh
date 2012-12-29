#!/bin/sh
for file in /usr/local/bin/*
do
	if [ -h $file ]
	then
		echo "Removing $file"
		sudo rm $file
	fi
done
