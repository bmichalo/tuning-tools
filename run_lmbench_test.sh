#!/bin/bash
#parallelism=(1 8 16 32)
#message_size=(8192 16384 65536 4m)
parallelism=(1 8)
message_size=(8192)
prior_best_result_Gbps=0
initialize_prior_best_result_Gbps=1

for i in "${message_size[@]}"
do
	for j in "${parallelism[@]}"
	do
		for k in {1..3}
		do
			#echo "bw_tcp -m $i -P $j 10.0.1.21:  " | tr -d '\n'
			test_cfg_string="bw_tcp-m$i-P$j"

			printf "%-10s%5s%3s%3d%s" "bw_tcp -m" $i "-P" $j "  10.0.1.21:  "

			pbench-user-benchmark --config=$test_cfg_string -- eval `numactl --cpunodebind=0 --membind=0 -- bw_tcp -m $i -P $j 10.0.1.21 &> see2.txt`
			#pbench-user-benchmark --config=$test_cfg_string -- eval "ls"

			answer_MBps=$(awk '{print $2}' see2.txt)
			#echo "$answer_MBps MBps ..... " | tr -d '\n'
			printf "%12.4f%s" $answer_MBps " MBps ..... "
			answer_Gbps=$(echo "scale=4;${answer_MBps} * 8/10^3" | bc -l)
			#echo "$answer_Gbps Gbps"
			printf "%9.4f%s\n" $answer_Gbps " Gbps"

			if [ "$initialize_prior_best_result_Gbps" -eq 1 ]; then
				prior_best_result_Gbps=$answer_Gbps
				initialize_prior_best_result_Gbps=0
			fi

			better_results=$(echo "scale=4; ${answer_Gbps} > ${prior_best_result_Gbps}" | bc -l)
			if [ 1 -eq  $better_results ]; then
				prior_best_result_Gbps=$answer_Gbps
				best_result="bw_tcp -m $i -P $j 10.0.1.21:  $answer_MBps MBps ..... $answer_Gbps Gbps"
				best_message_size=$i
				best_parallelism=$j
			fi
		done
	done
done

echo "========================================================================================="
echo "Best results:  $best_result "
echo ""
echo ""
echo "Running 5 tests using message size = $best_message_size, parallelism = $best_parallelism:"
echo "-----------------------------------------------------------------------------------------"

sample_set_array=()
initialize_prior_best_result_Gbps=1
prior_best_result_Gbps=0
prior_worst_result_Gbps=0
worst_results=0
better_results=0

for k in {1..5}
do
	# echo "bw_tcp -m $best_message_size -P $best_parallelism 10.0.1.21:  " | tr -d '\n';bw_tcp -m $best_message_size -P $best_parallelism 10.0.1.21 &> see2.txt
	echo "bw_tcp -m $best_message_size -P $best_parallelism 10.0.1.21:  " | tr -d '\n'
	test_cfg_string="bw_tcp-m$best_message_size-P$best_parallelism_FINAL_VALIDATION_$k"
	bw_tcp -m $best_message_size -P $best_parallelism 10.0.1.21 &> see2.txt
	pbench-user-benchmark --config=$test_cfg_string -- eval `numactl --cpunodebind=0 --membind=0 -- bw_tcp -m $i -P $j 10.0.1.21 &> see2.txt`
	answer_MBps=$(awk '{print $2}' see2.txt)
	echo "$answer_MBps MBps ..... " | tr -d '\n'
	answer_Gbps=$(echo "scale=4;${answer_MBps} * 8/10^3" | bc -l)
	echo "$answer_Gbps Gbps"


	if [ "$initialize_prior_best_result_Gbps" -eq 1 ]; then
		prior_best_result_Gbps=$answer_Gbps
		prior_worst_result_Gbps=$answer_Gbps
		initialize_prior_best_result_Gbps=0
	fi

	better_results=$(echo "scale=4; ${answer_Gbps} > ${prior_best_result_Gbps}" | bc -l)
	if [ 1 -eq  $better_results ]; then
		prior_best_result_Gbps=$answer_Gbps
	fi

	worst_results=$(echo "scale=4; ${answer_Gbps} < ${prior_worst_result_Gbps}" | bc -l)
	if [ 1 -eq  $worst_results ]; then
		prior_worst_result_Gbps=$answer_Gbps
	fi

	if [ $k -eq 1 ]; then
		sample_set_array=$answer_Gbps
	else
		sample_set_array=(${sample_set_array[@]} ${answer_Gbps})
	fi
done

#
# Now calculate the mean and standared deviation of the population set
#
total=0

#
# 1.  Find the mean
#
sample_set_size=${#sample_set_array[@]}

for throughput_result in "${sample_set_array[@]}"
do
	total=$(echo "scale=4;${total}+${throughput_result}" | bc -l)
done

mean=$(echo "scale=4;${total}/${sample_set_size}" | bc -l)


#
# 2.  For each element in the sample set, find the square of its distance to the mean
#
squared_distance_from_mean_array=()

for (( sample_set_element=0; sample_set_element<${#sample_set_array[@]}; sample_set_element++ )); do
	squared_set_element=$(echo "scale=4;(${sample_set_array[$sample_set_element]}-${mean}) * (${sample_set_array[$sample_set_element]}-${mean})" | bc -l)
	if [ $sample_set_element -eq 0 ]; then
		squared_distance_from_mean_array=(${squared_set_element})
	else
		squared_distance_from_mean_array=(${squared_distance_from_mean_array[@]} ${squared_set_element})
	fi
done

#
# Sum the values from step 2
#
total_sum_of_squares=0
for (( i=0; i<${#squared_distance_from_mean_array[@]}; i++ )); do
	total_sum_of_squares=$(echo "scale=4;${total_sum_of_squares} + ${squared_distance_from_mean_array[$i]}" | bc -l)
done

#
# Divide the total sum of the squares by the number of elements 
#
sum_squares_div_sample_set_size=$(echo "scale=4;${total_sum_of_squares} / ${sample_set_size}" | bc -l)

#
# Take square root to finally find standard deviation
#
std_dev=$(echo "scale=4;sqrt($sum_squares_div_sample_set_size)" | bc -l)

printf "\n"
printf "%s\n"              "*********************************"
printf "%s\n"              "********* Final Results *********"
printf "%s\n"              "*********************************"
printf "%-10s %8.4f %s\n" "Best results ....." $prior_best_result_Gbps "Gbps"
printf "%-10s %8.4f %s\n" "Worst results ...." $prior_worst_result_Gbps "Gbps"
printf "%-10s %8.4f %s\n" "Mean ............." $mean "Gbps"
printf "%-10s %8.4f %s\n" "Std dev .........." $std_dev "Gbps"
printf "\n"
