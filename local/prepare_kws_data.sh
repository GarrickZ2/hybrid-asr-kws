#!/usr/bin/env bash

echo "Loading Config"
. ./cmd.sh
. ./path.sh
. ./conf/common_vars.sh || exit 1;
. ./conf/lang.conf || exit 1;
echo "Finish Loading Config"


in_dir=`utils/make_absolute.sh $1`
ou_dir=`utils/make_absolute.sh $2`
lang=`utils/make_absolute.sh $3`
kw_dir=$in_dir/kws_data

mkdir -p $kw_dir
mkdir -p $ou_dir

# Create the ECF file
if [ ! -f $kw_dir/.ecf.done ]; then
    ./local/create_ecf_file.sh $in_dir/wav.scp $kw_dir/ecf.xml
    touch $kw_dir/.ecf.done
else
    echo "ECF.XML has been created, won't do it again"
fi

# Create the kwlist
if [ ! -f $kw_dir/keyword.txt ]; then
    echo "You can provide your own keywords in keyword.txt in the following format"
    echo "<word1>"
    echo "<word2>"
    echo "<word3>"
    echo "Now we use the template keyword for a quick start"
    cp ./conf/keyword.txt $kw_dir/keyword.txt
fi

if [ ! -f $kw_dir/.kwlist.done ]; then
    ./local/prepare_kwlist.sh $kw_dir
    touch $kw_dir/.kwlist.done
fi

# Create RTTM file
if [ ! -f $kw_dir/.rttm.done ]; then
    ./steps/segmentation/convert_utt2spk_and_segments_to_rttm.py $in_dir/utt2spk $in_dir/segments $kw_dir/rttm
    touch $kw_dir/.rttm.done
fi

# Setup KWS
if [ ! -f $kw_dir/.prep.done ]; then
    ./local/kws_data_prep.sh $lang $in_dir $kw_dir
    touch $kw_dir/.prep.done
fi

if [ ! -f $kw_dir/.setup.done ]; then
#    ./local/kws_setup.sh \
#    --case_insensitive false\
#    --rttm-file $kw_dir/rttm \
#    $kw_dir/ecf.xml $kw_dir/keyword.txt $lang $in_dir
    touch $kw_dir/.setup.done
fi

echo "Congrats!Data Preparation Finished"
