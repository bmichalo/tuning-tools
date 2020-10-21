#!/bin/bash
parallelism=(1 8 16 32)
message_size=(8192 16384 65536)
prior_best_result_Gbps=0
initialize_prior_best_result_Gbps=1

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

			if [ "$initialize_prior_best_result_Gbps" -eq 1 ]; then
				prior_best_result_Gbps=$answer_Gbps
				initialize_prior_best_result_Gbps=0
			fi

			better_results=$(echo "scale=4; ${answer_Gbps} > ${prior_best_result_Gbps}" | bc -l)
			if [ 1 -eq  $better_results ]; then
				echo "Inside if statement"
				prior_best_result_Gbps=$answer_Gbps
				best_result="bw_tcp -m $i -P $j 10.0.1.21:  $answer_MBps MBps ..... $answer_Gbps Gbps"
			fi
		done
	done
done

echo ""
echo ""
echo "==========================================="
echo "Best results:  $best_result "
echo ""
			
