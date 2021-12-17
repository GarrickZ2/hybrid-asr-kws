#!/usr/bin/env bash
# Whole file written by zz2888

echo "Loading Config"
. ./cmd.sh
. ./path.sh
. ./conf/common_vars.sh || exit 1;
. ./conf/lang.conf || exit 1;
echo "Finish Loading Config"

train_dir=$1
output_dir=$2

mkdir -p $output_dir

./utils/subset_data_dir.sh --per-spk $train_dir 5 $output_dir

