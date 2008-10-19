#!/bin/sh

# Keep in mind this is sh code. not bash.  No bashishms allowed!
# to use OnlyShowIn and NotShowIn, set the DESKTOP_ENVIRONMENT variable (this is not a standardized variable.  I came up with it)

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


# This function tries to execute a command for an entry
# $1 Command
try_exec (){
if test "x$1" != "x"
then
	read executable args <<< "$@" 2>/dev/null
	base=`basename $executable`
	if test "$base" = "$executable" # we did not get a full path, just a basename
	then
		path=`which "$base" 2>/dev/null`
		if test $? -eq 0 -a -x "$path"
		then
			echo "Executing $path $args & ...."
			$path $args &
			return 0
		else
			return 2
		fi
	else
		if test -x "$executable"
		then
			echo "Executing $executable $args & ...."
			$executable $args &
			return 0
		else
			return 3
		fi
	fi
else
	return 1
fi
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
	
	cmd=`grep -E "^TryExec=" "$file" | cut -d'=' -f2`
	try_exec $cmd
	if test $? -gt 0
	then
		# Exec key is not documented in spec but all my .desktop files have this, so ...
		cmd=`grep -E "^Exec=" "$file" | cut -d'=' -f2`
		try_exec $cmd
		if test $? -gt 0
		then
			echo "Could not find an executable in \$PATH for $cmd ..." >&2
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