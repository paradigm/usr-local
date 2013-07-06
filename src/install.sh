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

echo "" > /tmp/usr-local-log

clean(){
	git clean -xdf
	git reset --hard >/tmp/usr-local-log 2>&1
}

apply_patch(){
	if [ -d /usr/local/patches/$package ]
	then
		echo "found patches"
		for patch in /usr/local/patches/$package/*
		do
			echo -n "  Patching with $patch...  "
			patch -p1 < $patch >/tmp/usr-local-log 2>&1
			if [ $? -eq 0 ]
			then
				echo "okay"
			else
				echo "FAILURE"
				echo "Try grepping through /tmp/usr-local-log"
				exit 1
			fi
		done
	fi
}

force_install_opt(){
	if ls | grep -q "^config.mk$"
	then
		sed "s,^PREFIX *=.*,PREFIX = /opt/$package," config.mk > config.mk2
		mv config.mk2 config.mk
	elif ls | grep -q "^Makefile$"
	then
		sed "s,^PREFIX *=.*,PREFIX = /opt/$package," Makefile > Makefile2
		mv Makefile2 Makefile
		sed "s,^prefix *?\?=.*,prefix = /opt/$package," Makefile > Makefile2
		mv Makefile2 Makefile
	fi
}

make_and_install_deps(){
	previous_source=""
	while /bin/true
	do
		make >/tmp/usr-local-log-make 2>&1
		if [ $? -eq 0 ]
		then
			return
		fi
		if grep -q "No such file or directory" /tmp/usr-local-log-make
		then
			for missing_file in $(awk -F: '/No such file or directory/{print$5}' /tmp/usr-local-log-make)
			do
				echo "missing file: $missing_file"
				echo "finding package..."
				if which apt-file >/dev/null 2>&1
				then
					sources=$(apt-file search "$missing_file" | grep "$missing_file$" | grep -- "-dev: " | awk -F":" '{print$1}')
					if [ "$previous_source" = "$sources" ]
					then
						echo "FAILED"
						echo "Already tried to install $sources"
						exit 1
					fi
					if [ $(echo $sources | wc -l) -gt 1 ]
					then
						echo "FAILED"
						echo "To many possible sources, aborting"
						echo "Possible sources:"
						echo "$sources"
						exit 1
					fi
					echo -n "Found, installing..."
					sudo apt-get install $sources
					if [ $? -ne 0 ]
					then
						echo "FAILED"
						echo "Could not automatically search for file, aborting"
						exit 1
					fi
				else
					echo "FAILED"
					echo "Could not automatically search for file, aborting"
					exit 1
				fi
			done
		else
			echo "FAILED"
			echo "make failed for some reason"
			exit 1
		fi
	done
}

make_install(){
	sudo make install >>/tmp/usr-local-log 2>&1
}

make_symlinks(){
	cd /opt/$package/bin
	for file in *
	do
		sudo ln -s /opt/$package/bin/$file /usr/local/bin/$file
		if [ $? -ne 0 ]
		then
			echo "FAILED"
			exit
		fi
	done
}

configure(){
	if [ -d /usr/local/configure_flags/$package ]
	then
		echo "found configure_flags"
		for flags in /usr/local/configure_flags/$package/*
		do
			echo "Running configure with flags:"
			cat $flags
			if ! ./configure $(cat $flags) >>/tmp/usr-local-log 2>&1
			then
				echo "FAILURE"
				echo "Try grepping through /tmp/usr-local-log"
				exit 1
			fi
		done
	fi
}

fix_permissions(){
	cd /opt/$package/
	sudo chmod a+rx /opt/$package/
	sudo find . -perm -u+x -exec chmod a+x {} \; && sudo find . -perm -u+r -exec chmod a+r {} \;
}

for cmd in "clean" "apply_patch" "force_install_opt" "configure" "make_and_install_deps" "make_install" "fix_permissions" "make_symlinks"
do
	for package in $packages
	do
		echo -n "Running $cmd for $package... "
		cd $starting_directory
		cd $package
		eval $cmd
		if [ $? -ne 0 ]
		then
			echo "FAILURE"
			exit 1
		fi
		echo "okay"
	done
done
echo "Done!"
