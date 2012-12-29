#!/bin/sh
starting_directory=$(pwd)
packages=$(ls | grep -v install.sh | grep -v uninstall.sh)

create_symlinks(){
	sudo find /opt/$package -perm -u+x -exec chmod a+x {} \; && sudo find /opt/$package -perm -u+r -exec chmod a+r {} \;
	for binary in /opt/$package/bin/*
	do
		sudo ln -sf $binary /usr/local/bin/
	done
}

for cmd in "make clean" "make" "sudo make install" "create_symlinks"
do
	for package in $packages
	do
		echo ""
		echo "running: $cmd for $package"
		echo ""
		cd $starting_directory
		cd $package
		eval $cmd
		if [ $? -ne 0 ]
		then
			echo "$cmd $package failed"
			exit 1
		fi
	done
done
