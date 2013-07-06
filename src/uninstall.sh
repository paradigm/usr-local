#!/bin/sh
starting_directory=$(pwd)

if [ $# -eq 0 ]
then
	packages=""
	cd /usr/local/src/
	for file in *
	do
		cd $starting_directory
		# ensure a directory, not a script like this file
		if [ -d $file ]
		then
			cd $file
			# ensure a git repo so we don't blow away something with git --reset
			# later
			if [ $(git rev-parse --show-toplevel) = $(pwd) ]
			then
				if [ -z "$packages" ]
				then
					packages="$file"
				else
					packages="$packages $file"
				fi
			fi
		fi
	done
else
	packages="$@"
fi

remove_symlinks(){
	cd /opt/$package/bin
	for file in *
	do
		if [ -h /usr/local/bin/$file ]
		then
			sudo rm /usr/local/bin/$file
			if [ $? -ne 0 ]
			then
				echo "FAILED"
				exit
			fi
		fi
	done
}

remove_package(){
	sudo rm -r /opt/$package
}

for package in $packages
do
	if [ -d /opt/$package ]
	then
		for cmd in "remove_symlinks" "remove_package"
		do
			echo -n "Running $cmd for $package... "
			eval $cmd
			if [ $? -ne 0 ]
			then
				echo "FAILURE"
				exit 1
			fi
			echo "okay"
		done
	else
		echo "Package $package already uninstalled."
	fi
done
echo "Done!"
