#!/bin/bash


function get_counter {
	if [ $3 == 'in' ]; then
		echo `cat /tmp/int |  grep "^\*\*${2}$" -A 5 | grep "${1}" | awk '{print $2}'`
	fi
	
	if [ $3 == 'out' ]; then
		echo `cat /tmp/int |  grep "^\*\*${2}$" -A 5 | grep ${1} | awk '{print $10}'`
	fi 
}

function final_output {
	echo 
	for i_name in ${int_names[*]}; do
		local FORMAT="Interface: %s - Total in: %d Total out: %d Max in: %d Max out: %d\n"
		printf "$FORMAT" $i_name ${iface["${i_name} total_in"]} ${iface["${i_name} total_out"]} ${iface["${i_name} max_i"]} ${iface["${i_name} max_o"]}
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
declare -a int_names=`cat /proc/net/dev | grep : |  awk -F ':' '{print $1}'`
declare -A iface

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

        	FORMAT="%s: In %d Out %d\n"
        	printf "$FORMAT" $i_name ${iface["${i_name} in"]} ${iface["${i_name} out"]}

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
