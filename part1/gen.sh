# Shell script to generate tbfiles and rtlfiles
# $1 = N, $2 = M, $3 = T, $4 = P

rm -r rtl_files_$1_$2_$3_$4
mkdir rtl_files_$1_$2_$3_$4

rm -r tbgen_$1_$2_$3_$4
mkdir tbgen_$1_$2_$3_$4

echo ">>> Generating Constant ROM File and TestBench"
cp -f tb_ref/* tbgen_$1_$2_$3_$4/.
cd tbgen_$1_$2_$3_$4
./testgen 1 $1 $2 $3 $4
cd ../

echo "\n>>> Auto Generating RTL"
perl gen_cnn.pl $1 $2 $3 $4 ./tbgen_$1_$2_$3_$4/const_$1_$2_$3_$4.txt | tee ./rtl_files_$1_$2_$3_$4/rtl_file_list
echo "RTL files and File List dumped in rtl_files_$1_$2_$3_$4 directory"

echo "\n>>> Compilation on generated files"
vlog -f  ./rtl_files_$1_$2_$3_$4/rtl_file_list ./tbgen_$1_$2_$3_$4/tb_conv_$1_$2_$3_$4.sv
