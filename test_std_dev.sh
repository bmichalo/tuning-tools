#!/bin/bash

sample_set_array=(1 2 3 4 5 10 18)
total=0


echo ${sample_set_array[*]}


#
# 1.  Find the mean
#
sample_set_size=${#sample_set_array[@]}
echo "sample set size = ${#sample_set_array[@]}"

for throughput_result in "${sample_set_array[@]}"
do
	total=$(echo "scale=4;${total}+${throughput_result}" | bc -l)
done

mean=$(echo "scale=4;${total}/${sample_set_size}" | bc -l)

echo "mean = $mean"


#
# 2.  For each element in the sample set, find the square of its distance to the mean
#
squared_distance_from_mean_array=()

for (( sample_set_element=0; sample_set_element<${#sample_set_array[@]}; sample_set_element++ )); do
	squared_set_element=$(echo "scale=4;(${sample_set_array[$sample_set_element]}-${mean}) * (${sample_set_array[$sample_set_element]}-${mean})" | bc -l)
	echo "$sample_set_element"
	if [ $sample_set_element -eq 0 ]; then
		squared_distance_from_mean_array=(${squared_set_element})
	else
		squared_distance_from_mean_array=(${squared_distance_from_mean_array[@]} ${squared_set_element})
	fi
done

echo "${squared_distance_from_mean_array[*]}"

#
# Sum the values from step 2
#
total_sum_of_squares=0
for (( i=0; i<${#squared_distance_from_mean_array[@]}; i++ )); do
	total_sum_of_squares=$(echo "scale=4;${total_sum_of_squares} + ${squared_distance_from_mean_array[$i]}" | bc -l)
done

echo "total_sum_of_squares = $total_sum_of_squares"
echo "sample_set_size = $sample_set_size"
#
# Divide the total sum of the squares by the number of elements 
#
sum_squares_div_sample_set_size=$(echo "scale=4;${total_sum_of_squares} / ${sample_set_size}" | bc -l)
echo "sum of the squares divided by the samples set size = $sum_squares_div_sample_set_size"

#
# Take square root to finally find standard deviation
#
std_dev=$(echo "scale=4;sqrt($sum_squares_div_sample_set_size)" | bc -l)
echo "std_dev = $std_dev"



exit

standardDeviation=$(
    echo "$myNumbers" |
        awk '{sum+=$1; sumsq+=$1*$1}END{print sqrt(sumsq/NR - (sum/NR)**2)}'
)
echo $standardDeviation


