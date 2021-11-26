#!/usr/bin/env bash

# Copyright 2014  Vimal Manohar, Johns Hopkins University (Author: Jan Trmal)
# Apache 2.0

#Begin configuration section

silence_segment_fraction=1.0  # What fraction of segment we should keep

#end configuration section
# This is not necessarily the top-level run.sh as it is in other directories.   see README.txt first.

. ./cmd.sh
. ./path.sh
. conf/common_vars.sh || exit 1;
. ./conf/lang.conf || exit 1;

[ -f local.conf ] && . ./local.conf

. ./utils/parse_options.sh

set -e           #Exit on non-zero return code from any command
set -o pipefail  #Exit if any of the commands in the pipeline will 
                 #return non-zero return code
set -u           #Fail on an undefined variable

#Later in the script we assume the run-1-main.sh was run (because we are using exp/tri4)
#So let's make it mandatory, instead of doing the work on our own.
[ ! -f data/raw_train_data/.done ] && echo "The source training data directory is not ready. Use the run-1-main.sh script to prepare it!" && exit 1

# Set the number of jobs and decode number of jobs
nj_max= $train_nj

# Transfer the relative data path in absolute path
train_data_dir=`utils/make_absolute.sh ./data/raw_train_data`

stage=$1

if [ $stage = 0 ]; then

  mkdir -p data/train_seg

  echo ---------------------------------------------------------------------
  echo "Preparing acoustic training lists in data/train on" `date`
  echo ---------------------------------------------------------------------
    cp data/train/text data/train_seg/text
    mv data/train_seg/text data/train_seg/text_orig
  
    num_silence_segments=$(cat data/train_seg/text_orig | awk '{if (NF == 2 && $2 == "<silence>") {print $0}}' | wc -l)
    num_keep_silence_segments=`perl -e "printf '%d', ($num_silence_segments * $silence_segment_fraction)"` 
    if [ $num_silence_segments -eq $num_keep_silence_segments ]; then
        # Keep all segments including silence segments
        cat data/train_seg/text_orig | awk '{if (NF == 2 && $2 == "<silence>") {print $1} else {print $0}}' > data/train_seg/text
    else
        # Keep only a fraction of silence segments

        cat data/train_seg/text_orig \
            | awk 'BEGIN{i=0} \
            { \
                if (NF == 2 && $2 == "<silence>") { \
                if (i<'$num_keep_silence_segments') { \
                    print $1; \
                    i++; \
                } \
            } else {print $0}\
        }' > data/train_seg/text
    fi
    #rm data/train_seg/text_orig
    utils/fix_data_dir.sh data/train_seg

    echo ---------------------------------------------------------------------
    echo "Starting plp feature extraction for data/train_seg in plp on" `date`
    echo ---------------------------------------------------------------------

    if $use_pitch; then
      steps/make_plp_pitch.sh --cmd "$train_cmd" --nj $train_nj \
        data/train_seg exp/make_plp_pitch/train_seg plp
    else
      steps/make_plp.sh --cmd "$train_cmd" --nj $train_nj \
        data/train_seg exp/make_plp/train_seg plp
    fi

    utils/fix_data_dir.sh data/train_seg
    steps/compute_cmvn_stats.sh data/train_seg exp/make_plp/train_seg plp
    utils/fix_data_dir.sh data/train_seg
fi

if [ $stage = 1 ]; then
    echo ---------------------------------------------------------------------
    echo "Training segmentation model in exp/tri4b_seg"
    echo ---------------------------------------------------------------------

    local/resegment/train_segmentation.sh \
        --boost-sil 1.0 --nj $train_nj --cmd "$decode_cmd" \
    exp/tri4 data/train_seg data/lang exp/tri4b_seg || exit 1

    echo ---------------------------------------------------------------------
    echo "Finished successfully on" `date`
    echo ---------------------------------------------------------------------
fi

exit 0