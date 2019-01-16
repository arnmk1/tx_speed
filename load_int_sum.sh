#!/bin/bash


function scale {
	
	let GB=1024*1024*1024
	let MB=1024*1024
	let KB=1024
	let B=1

	if [ $1 -eq 0 ]; then
		echo "$1"
		return 1
	fi

	if [ $1 -gt $GB ]; then
		scl=$GB
		o_rscl='GB/s'
		o_scl='GB'

	elif [ $1 -gt $MB ]; then
		scl=$MB
		o_rscl='MB/s'
		o_scl='MB'

	elif [ $1 -gt $KB ]; then
		scl=$KB
		o_rscl='KB/s'
		o_scl='KB'

	elif [ $1 -gt $B ]; then
		scl=$B
		o_rscl='B/s'
		o_scl='B'
	fi 

	out=$(echo "scale=3; $1/$scl" | bc)

	if [ "$2" == 's' ]; then
		echo "$out $o_rscl"
	else 
		echo "$out $o_scl" 
	fi

}

function get_counter {
	if [ $3 == 'in' ]; then
		echo `cat /tmp/int |  grep "^\*\*${2}$" -A ${tnum_int} | grep ${1} | awk '{print $2}'`
	fi
	
	if [ $3 == 'out' ]; then
		echo `cat /tmp/int |  grep "^\*\*${2}$" -A ${tnum_int} | grep ${1} | awk '{print $10}'`
	fi 
}

function final_output {
	echo 
	for i_name in ${int_names[*]}; do
		local FORMAT="Interface: %s - Total in: %s Total out: %s Max in: %s Max out: %s\n"
		printf "$FORMAT" $i_name "$(scale ${iface["${i_name} total_in"]})" "$(scale ${iface["${i_name} total_out"]})" "$(scale ${iface["${i_name} max_i"]} 's')" "$(scale ${iface["${i_name} max_o"]} 's')"
	done

	# kill catcher and rm tmp script
	pkill -9 $FCATCHER && echo "Kill catcher"
	rm ./$FCATCHER
}


# src text catcher
FCATCHER='catcher.sh'

catcher=`cat << 'CATCHER' 
#!/bin/bash


counter=1
# clean file counter
>/tmp/int

while true; do
        echo "**$counter" >> /tmp/int;
        cat /proc/net/dev | grep : >> /tmp/int;
        sleep 1;
        ((counter++))
done
CATCHER`
# end src 

# rm old catche if exsist 
rm ./$FCATCHER 2>/dev/null

# make new catcher 
echo "$catcher" > ./$FCATCHER
chmod 755 ./$FCATCHER

# arrays interfaces and countes 
declare -a int_names=(`cat /proc/net/dev | grep : |  awk -F ':' '{print $1}'`)
declare -A iface

# total number interfaces
tnum_int=${#int_names[*]}

# kill old catcher 
pkill -9 $FCATCHER && echo "Kill old catcher"

# start catcher
nohup ./$FCATCHER >/dev/null&
sleep 1

# init counters
counter=1

for i_name in ${int_names[*]}; do
	iface["${i_name} t1_in"]=$(get_counter $i_name $counter 'in')	 
	iface["${i_name} t1_out"]=$(get_counter $i_name $counter 'out')	 
	iface["${i_name} max_i"]=0	 
	iface["${i_name} max_o"]=0	 
done
((counter++))


# set trap interrupt Ctr + C 
trap 'final_output; exit 1' 2

# main cycle
while true; do
	for i_name in ${int_names[*]}; do
	
		iface["${i_name} t2_in"]=$(get_counter $i_name $counter 'in')	 
		iface["${i_name} t2_out"]=$(get_counter $i_name $counter 'out')	 
		iface["${i_name} in"]=$((${iface["${i_name} t2_in"]}-${iface["${i_name} t1_in"]}))
		iface["${i_name} out"]=$((${iface["${i_name} t2_out"]}-${iface["${i_name} t1_out"]}))
		iface["${i_name} t1_in"]=${iface["${i_name} t2_in"]}
		iface["${i_name} t1_out"]=${iface["${i_name} t2_out"]}

		iface["${i_name} total_in"]=$((${iface["${i_name} total_in"]}+${iface["${i_name} in"]}))
		iface["${i_name} total_out"]=$((${iface["${i_name} total_out"]}+${iface["${i_name} out"]}))

        	FORMAT="%s: In %s Out %s\n"
        	printf "$FORMAT" $i_name "$(scale ${iface["${i_name} in"]} 's')" "$(scale ${iface["${i_name} out"]} 's')"

	        if [ ${iface["${i_name} max_o"]} -le ${iface["${i_name} out"]} ]; then
        		iface["${i_name} max_o"]=${iface["${i_name} out"]}
        	fi
        
       		if [ ${iface["${i_name} max_i"]} -le ${iface["${i_name} in"]} ]; then
        		iface["${i_name} max_i"]=${iface["${i_name} in"]}
        	fi
	done
	((counter++))
        sleep 1

        clear

done
