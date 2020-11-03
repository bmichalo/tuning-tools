#!/bin/bash
#parallelism=(1 8 16 32)
#message_size=(4m)
prior_best_result_Gbps=0
initialize_prior_best_result_Gbps=1

while getopts p:m:s: flag
do
	case "${flag}" in
		p) parallelism=${OPTARG};;
		m) message_size=${OPTARG};;
		s) sample_set_size=${OPTARG};;
	esac
done

echo "parallelism=$parallelism"
echo "message_size=$message_size"
echo "sample_set_size=$sample_set_size"


for k in $(eval echo "{1..$sample_set_size}")
do
	test_cfg_string="bw_tcp-m4m-P$parallelism-TEST-numactl_-C_0-15_64-79-membind_0-server_rxadaptoffusecrx2000rxframes65535$k"
	echo "test_cfg_string = $test_cfg_string"

	printf "%-10s%3d%s" "bw_tcp -m 4m -P" $parallelism "  10.0.1.21:  "

	#pbench-user-benchmark --config=$test_cfg_string -- eval "numactl --cpunodebind=0 --membind=0 -- bw_tcp -m 4m -P $parallelism 10.0.1.21" | tee -i see2.txt
	pbench-user-benchmark --config=$test_cfg_string -- eval "numactl -C 0-15,64-79 --membind=0 -- bw_tcp -m 4m -P $parallelism 10.0.1.21" | tee -i see2.txt
	#pbench-user-benchmark --config=$test_cfg_string -- eval "bw_tcp -m 4m -P $parallelism 10.0.1.21" | tee -i see2.txt
	answer_MBps=$(cat see2.txt | head -2 | tail -1 | awk '{print $2}')
	printf "%12.4f%s" $answer_MBps " MBps ..... "
	answer_Gbps=$(echo "scale=4;${answer_MBps} * 8/10^3" | bc -l)
	printf "%9.4f%s\n" $answer_Gbps " Gbps"

	if [ "$initialize_prior_best_result_Gbps" -eq 1 ]; then
		prior_best_result_Gbps=$answer_Gbps
		initialize_prior_best_result_Gbps=0
		best_result="bw_tcp -m $i -P $parallelsim 10.0.1.21:  $answer_MBps MBps ..... $answer_Gbps Gbps"
		best_message_size=$i
	fi


	better_results=$(echo "scale=4; ${answer_Gbps} > ${prior_best_result_Gbps}" | bc -l)
	if [ 1 -eq  $better_results ]; then
		prior_best_result_Gbps=$answer_Gbps
		best_result="bw_tcp -m $i -P $parallelism 10.0.1.21:  $answer_MBps MBps ..... $answer_Gbps Gbps"
		best_message_size=$i
	fi
done

echo "========================================================================================="
echo "Best results:  $best_result "
echo "========================================================================================="
