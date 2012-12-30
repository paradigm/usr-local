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

install_opt(){
	if ls | grep -q "config.mk"
	then
		sed "s,^PREFIX \?=.*,PREFIX = /opt/$package," config.mk > config.mk2
		mv config.mk2 config.mk
	else
		sed "s,^PREFIX \?=.*,PREFIX = /opt/$package," Makefile > Makefile2
		mv Makefile2 Makefile
		sed "s,^prefix \??\?=.*,prefix = /opt/$package," Makefile > Makefile2
		mv Makefile2 Makefile
	fi
}

clean_up(){
	git reset --hard
}

for cmd in "clean_up" "install_opt" "make" "sudo make install" "create_symlinks" "clean_up"
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
