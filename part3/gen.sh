# Shell script to generate tbfiles and rtlfiles
# $1 = N, $2 = M1, $3 = M2, $4 = M3, $5 = T, $6 = P, 

rm -r -f rtl_files_$1_$2_$3_$4_$5_$6
mkdir rtl_files_$1_$2_$3_$4_$5_$6

rm -r -f tbgen_$1_$2_$3_$4_$5_$6
mkdir tbgen_$1_$2_$3_$4_$5_$6

rm -r -f synth_$1_$2_$3_$4_$5_$6
mkdir synth_$1_$2_$3_$4_$5_$6

echo ">>> Generating Constant ROM File and TestBench"
cp -f tb_ref/* tbgen_$1_$2_$3_$4_$5_$6/.
cd tbgen_$1_$2_$3_$4_$5_$6
./testgen 2 $1 $2 $3 $4 $5 $6
cd ../

echo "\n>>> Auto Generating RTL"
perl gen_3layered_cnn.pl $1 $2 $3 $4 $5 $6 ./tbgen_$1_$2_$3_$4_$5_$6/const_$1_$2_$3_$4_$5_$6.txt | tee ./rtl_files_$1_$2_$3_$4_$5_$6/rtl_file_list
echo "RTL files and File List dumped in rtl_files_$1_$2_$3_$4_$5_$6 directory"

echo "\n>>> Compilation and Simulating generated files"
cd tbgen_$1_$2_$3_$4_$5_$6
vlog -f  ../rtl_files_$1_$2_$3_$4_$5_$6/rtl_file_list ./tb_multi_$1_$2_$3_$4_$5_$6.sv
vsim tb_multi_$1_$2_$3_$4_$5_$6 -c -do "run -all"
cd ../

echo "\n>>> Creating synthesis directory"
set P1=`cat log.txt | grep "final P1" | sed 's/final P1 = //'`
echo $P1
set P2=`cat log.txt | grep "final P2" | sed 's/final P2 = //'`
echo $P2
set P3=`cat log.txt | grep "final P3" | sed 's/final P3 = //'`
echo $P3
cd synth_ref
perl gensynth.pl $1 $2 $3 $4 $5 $6 $P1 $P2 $P3
cat synth1.tcl synth2.tcl > runsynth.tcl
cd ../
cp -f synth_ref/runsynth.tcl synth_$1_$2_$3_$4_$5_$6/.
cp -f synth_ref/setupdc.tcl synth_$1_$2_$3_$4_$5_$6/.





