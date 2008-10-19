#!/bin/sh

# Keep in mind this is sh code. not bash.  No bashishms allowed!
# to use OnlyShowIn and NotShowIn, set the DESKTOP_ENVIRONMENT variable (this is not a standardized variable.  I came up with it)

# WORK IN PROGRESS !! DOES NOT WORK !! 

echo " ** dautostart starting..."

# This functions maintains the list of desktop files to be used.  It adds absolute paths to the list and removes 'overruled' items.
updatelist () {
	#echo "**** updatelist called with arg $1"
	dir=`echo "$1" | sed 's#/$##'`
	new_list=`ls -1 $1/autostart/*.desktop 2>/dev/null`
	# copy full_list to old_list. go over new items and add them at the end. remove old item if it becomes invalid.
	while read new
	do
		if test "x$new" != "x"
		then
			echo "Checking for inclusion $new ..."
			new_base=`basename "$new"`
			found=no
			if test "x$full_list" != "x"
			then
				old_list=$full_list
				full_list=
				while read old
				do
					old_base=`basename "$old"`
					if test "x$new_base" != "x" -a "x$old_base" != "x"
					then
						if test "$new_base" != "$old_base"
						then
							if test "x$full_list" = "x"
							then
								full_list="$old"
							else
								full_list="$full_list
$old"
							fi
						fi
					fi
				done <<< "$old_list"
			fi
		
			if test "x$new" != "x"
			then
				if test "x$full_list" = "x"
				then
					full_list="$new"
				else
					full_list="$full_list
$new"
				fi
			fi
		fi
	done <<< "$new_list"
}

# This function processes all entries of the list and does whatever needs to be done.
process_entries () {
while read file
do
	echo "Processing $file ..."
	if grep -q -E "^Hidden=true" "$file"
	then
		break
	fi
	if test "x$DESKTOP_ENVIRONMENT" != "x" #if we don't know which DE this is, we can't use the variables OnlyShowIn and NotShowIn
	then
		# Note that the autostart specs mentions "a list of strings identifying the DE's". We cannot be 100% accurate.
		if grep -Eq "^OnlyShowIn=" "$file"
		then
			if grep -E "^OnlyShowIn=" "$file" | grep -qv "$DESKTOP_ENVIRONMENT"
			then
				break
			fi
		fi
		if grep -E "^NotShowIn=" "$file" | grep -q "$DESKTOP_ENVIRONMENT"
		then
			break
		fi
	fi
	
	try_exec=`grep -E "^TryExec=" "$file" | cut -d'=' -f2`
	if test "$try_exec" && test -x "$try_exec"
	then
		which "$try_exec"
		echo "executing $try_exec ...."
		#$try_exec &
	else
		# Exec key is not documented in spec but all my .desktop files have this, so ...
		exec_cmd=`grep -E "^Exec=" "$file" | cut -d'=' -f2`
		if test "$exec_cmd" && test -x "$exec_cmd"
		then
			echo "executing $exec_cmd ...."
		#	$exec_cmd &
		fi
	fi

done <<< "$full_list"
}


if test "x$XDG_CONFIG_HOME" = "x"
then
	XDG_CONFIG_HOME=$HOME/.config
fi
if test "x$XDG_CONFIG_DIRS" = "x"
then
	XDG_CONFIG_DIRS=/etc/xdg/autostart
fi

for dir in `echo $XDG_CONFIG_DIRS:$XDG_CONFIG_HOME | sed 's/:/\t/g'`
do
	updatelist "$dir"
done

process_entries

echo " ** dautostart done..."