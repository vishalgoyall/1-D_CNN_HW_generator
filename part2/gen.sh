# Shell script to generate tbfiles and rtlfiles
# $1 = N, $2 = M, $3 = T, $4 = P, 

rm -r -f rtl_files_$1_$2_$3_$4
mkdir rtl_files_$1_$2_$3_$4

rm -r -f tbgen_$1_$2_$3_$4
mkdir tbgen_$1_$2_$3_$4

#rm -r -f synth_$1_$2_$3_$4
#mkdir synth_$1_$2_$3_$4

echo ">>> Generating Constant ROM File and TestBench"
cp -f tb_ref/* tbgen_$1_$2_$3_$4/.
cd tbgen_$1_$2_$3_$4
./testgen 1 $1 $2 $3 $4
cd ../

echo "\n>>> Auto Generating RTL"
perl gen_cnn.pl $1 $2 $3 $4 ./tbgen_$1_$2_$3_$4/const_$1_$2_$3_$4.txt | tee ./rtl_files_$1_$2_$3_$4/rtl_file_list
echo "RTL files and File List dumped in rtl_files_$1_$2_$3_$4 directory"

echo "\n>>> Compilation and Simulating generated files"
cd tbgen_$1_$2_$3_$4
vlog -f  ../rtl_files_$1_$2_$3_$4/rtl_file_list ./tb_conv_$1_$2_$3_$4.sv
vsim tb_conv_$1_$2_$3_$4 -c -do "run -all"
cd ../

#echo "\n>>> Creating synthesis directory"
#cd synth_ref
#perl gensynth.pl $1 $2 $3 $4
#cat synth1.tcl synth2.tcl > runsynth.tcl
#cd ../
#cp -f synth_ref/runsynth.tcl synth_$1_$2_$3_$4/.
#cp -f synth_ref/setupdc.tcl synth_$1_$2_$3_$4/.





