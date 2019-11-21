# Shell script to run perl
# $1 = N, $2 = M, $3 = T, $4 = P, $5 = constantfile.txt
echo ">>Auto Generating RTL using inputs provided"
perl gen_cnn.pl $1 $2 $3 $4 $5 | tee rtl_file_list
