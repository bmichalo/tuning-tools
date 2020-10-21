#!/bin/bash
parallelism=(1 8 16 32)
message_size=(8192 16384 65536)
for i in "${message_size[@]}"
do
	for j in "${parallelism[@]}"
	do
		for k in {1..3}
		do
			echo "bw_tcp -m $i -P $j 10.0.1.21:  " | tr -d '\n';bw_tcp -m $i -P $j 10.0.1.21 &> see2.txt
			answer_MBps=$(awk '{print $2}' see2.txt)
			echo "$answer_MBps MBps ..... " | tr -d '\n'
			answer_Gbps=$(echo "scale=4;${answer_MBps} * 8/10^3" | bc -l)
			echo "$answer_Gbps Gbps"
		done
	done
done
			
