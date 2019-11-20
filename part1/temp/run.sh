rm -r work
echo "++++++++++++ START COMPILATION ++++++++++"
vlog -f ../rtl_file_list tb_conv_128_32_8_1.sv
echo "++++++++++++ COMPILATION DONE ++++++++++"

echo "++++++++++++ Launch TestBench ++++++++++"
if [ $1 = 'gui' ]; 
then
	vsim tb_conv_128_32_8_1 +acc
else
	vsim tb_conv_128_32_8_1 -c -do "run -all" 
fi
echo "++++++++++++ Exit TestBench ++++++++++"

