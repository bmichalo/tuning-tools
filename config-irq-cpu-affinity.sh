#!/bin/bash
while getopts n:a:b: flag
do
	case "${flag}" in
		n) numa_node=${OPTARG};;
		a) iface1=${OPTARG};;
		b) iface2=${OPTARG};;
	esac
done
echo "NUMA node: $numa_node";
echo "Network device 1: $iface1";
echo "Network device 2: $iface2";

#
# Obtain CPU list associated with NUMA node
#
cpu_list=`numactl -H | grep "node $numa_node.*cpus" | sed 's/^[^:]*: //g'`

echo $cpu_list
array_cpu_list=($cpu_list)
num_of_cpus=${#array_cpu_list[@]}
echo "Number of CPUs = $num_of_cpus"

max_num_combined_channels_iface1=`ethtool -l $iface1 | sed '6,6!d' | awk '{print $2}'`
echo "max_num_combined_channels_iface1 = $max_num_combined_channels_iface1"



#
# Set network devices online
#
echo "Enabling network devices"

if [ -n "$iface1" ]; then
	#ifup $iface1
	if [[ $num_of_cpus -gt $max_num_combined_channels_iface1 ]]; then
		num_of_channels=$max_num_combined_channels_iface1
	else
		num_of_channels=$num_of_cpus
	fi
	pci_address_iface1=`ethtool -i $iface1 | grep bus-info | sed 's/^[^:]*: //g'`
	num_of_net_devices=1
else
	echo "Need to specify at least one network interface.  Exiting..."
	exit 1
fi

if [ -n "$iface2" ]; then
	#ifup $iface2
	num_of_channels=$(($num_of_cpus/2))
	pci_address_iface2=`ethtool -i $iface2 | grep bus-info | sed 's/^[^:]*: //g'`
	num_of_net_devices=2
fi

echo "Number of channels / interface = $num_of_channels"
echo "PCIe address of network device 1:  $pci_address_iface1"


#
# Set number of channels per interface
#
ethtool -L $iface1 combined $num_of_channels
echo "Channel defintion for network device $iface1"
ethtool -l $iface1


if [ -n "$iface2" ]; then
        echo "PCIe address of network device 2:  $pci_address_iface2"
	ethtool -L $iface2 combined $num_of_channels
	echo "Channel defintion for network device $iface2"
	ethtool -l $iface2
fi

tuna --socket=0 -q mlx5_comp\*
echo "ens3f0 IRQ CPU affinity"
#tuna --show_irqs | grep mlx5 | grep c4:00.0
tuna --show_irqs | grep mlx5_comp | grep $pci_address_iface1 
#echo "ens3f1 IRQ CPU affinity"
#tuna --show_irqs | grep mlx5 | grep c4:00.1
#tuna --show_irqs | grep mlx5_comp | grep $pci_address_iface2

systemctl stop irqbalance
iptables -F

#cpu_list="0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 64 65 66 67 68 69 70 71 72 73 74 75 76 77 78 79"

array_cpu_list_iface1=()
array_cpu_list_iface2=()


if [ -n "$iface2" ]; then
	for (( i=0; i<${#array_cpu_list[@]}/4; i++ )); do
		cpu=${array_cpu_list[$i]}
		#echo "${array_cpu_list[$i]}" > /proc/irq/$irq/smp_affinity_list
		#echo "CPU = ${array_cpu_list[$i]}" 
		#echo "CPU list 0 ${array_cpu_list[$i]}" 
		#echo "CPU list 0 ${array_cpu_list[$((i+16))]}" 
		if [ $i -eq 0 ]; then
			array_cpu_list_iface1=(${array_cpu_list[$i]} ${array_cpu_list[$((i+16))]})
			array_cpu_list_iface2=(${array_cpu_list[$((i+8))]} ${array_cpu_list[$((i+24))]})
		else
			array_cpu_list_iface1=(${array_cpu_list_iface1[@]}, ${array_cpu_list[$i]}, ${array_cpu_list[$((i+16))]})
			array_cpu_list_iface2=(${array_cpu_list_iface2[@]}, ${array_cpu_list[$((i+8))]}, ${array_cpu_list[$((i+24))]})

		fi
	done

: << 'DEBUG'
	echo "sizeof(array_cpu_list_iface1 = ${#array_cpu_list_iface1[@]}"

	for (( i=0; i<${#array_cpu_list_iface1[@]}; i++ )); do
		echo -e "array_cpu_list_iface1, CPU[$i] = ${array_cpu_list_iface1[$i]} \n" 
	done

	echo "sizeof(array_cpu_list_iface2 = ${#array_cpu_list_iface2[@]}"

	for (( i=0; i<${#array_cpu_list_iface2[@]}; i++ )); do
		echo -e "array_cpu_list_iface2, CPU[$i] = ${array_cpu_list_iface2[$i]} \n" 
	done
DEBUG

else
	echo "Just a single CPU list"
	array_cpu_list_iface1=("${array_cpu_list[@]}")
fi






irq_list_iface1=`grep "mlx5_comp" /proc/interrupts | grep $pci_address_iface1 | cut -d: -f1`
array_irq_list_iface1=($irq_list_iface1)
echo "Number of IRQs iface1= ${#array_irq_list_iface1[@]}"

for (( i=0; i<${#array_irq_list_iface1[@]}; i++ )); do
        irq=${array_irq_list_iface1[$i]}
        #echo "${array_cpu_list_iface1[$i]}" > /proc/irq/$irq/smp_affinity_list
	cpu_in_use_by_irq=`cat /proc/irq/$irq/smp_affinity_list`
	echo "iface1: IRQ $irq uses CPU $cpu_in_use_by_irq"
        #echo "IRQ = ${array_irq_list[$i]}" 
done


echo "iface1:  Adjusting IRQ / CPU affinity for unique assignment pairings..." 


echo "size(array_cpu_list_iface1[@]) = ${#array_cpu_list_iface1[@]}"



for (( i=0; i<${num_of_channels}; i++ )); do
        irq=${array_irq_list_iface1[$i]}
        echo "${array_cpu_list_iface1[$i]}" > /proc/irq/$irq/smp_affinity_list
	cpu_in_use_by_irq=`cat /proc/irq/$irq/smp_affinity_list`
	echo "NEW: iface1: IRQ $irq uses CPU $cpu_in_use_by_irq"
        #echo "IRQ = ${array_irq_list[$i]}" 
done

#exit

if [ -n "$iface2" ]; then
	irq_list_iface2=`grep "mlx5_comp" /proc/interrupts | grep $pci_address_iface2 | cut -d: -f1`
	array_irq_list_iface2=($irq_list_iface2)
	echo "Number of IRQs iface2= ${#array_irq_list_face2[@]}"

	for (( i=0; i<${#array_irq_list_iface2[@]}; i++ )); do
		irq=${array_irq_list_iface1[$i]}
		#echo "${array_cpu_list_iface1[$i]}" > /proc/irq/$irq/smp_affinity_list
		cpu_in_use_by_irq=`cat /proc/irq/$irq/smp_affinity_list`
		echo "iface2: IRQ $irq uses CPU $cpu_in_use_by_irq"
		#echo "IRQ = ${array_irq_list[$i]}" 
	done


	echo "iface2:  Adjusting IRQ / CPU affinity for unique assignment pairings..." 


	echo "size(array_cpu_list_iface2[@]) = ${#array_cpu_list_iface2[@]}"



	for (( i=0; i<${#array_cpu_list_iface2[@]}; i++ )); do
		irq=${array_irq_list_iface2[$i]}
		echo "${array_cpu_list_iface2[$i]}" > /proc/irq/$irq/smp_affinity_list
		cpu_in_use_by_irq=`cat /proc/irq/$irq/smp_affinity_list`
		echo "NEW: iface2: IRQ $irq uses CPU $cpu_in_use_by_irq"
		#echo "IRQ = ${array_irq_list[$i]}" 
	done
fi

