#!/usr/bin/env bash

echo "Loading Config"
. ./cmd.sh
. ./path.sh
. ./conf/common_vars.sh || exit 1;
. ./conf/lang.conf || exit 1;
echo "Finish Loading Config"


in_dir=`utils/make_absolute.sh $1`
lang=`utils/make_absolute.sh $2`
iv_kw_dir=$in_dir/iv_kws
oov_kw_dir=$in_dir/oov_kws

mkdir -p $iv_kw_dir
mkdir -p $oov_kw_dir

# Create the ECF file
if [ ! -f $iv_kw_dir/.ecf.done ]; then
    ./local/create_ecf_file.sh $in_dir/wav.scp $iv_kw_dir/ecf.xml
    cp $iv_kw_dir/ecf.xml $oov_kw_dir/ecf.xml
    touch $iv_kw_dir/.ecf.done
else
    echo "ECF.XML has been created, won't do it again"
fi

# Create the kwlist
if [ ! -f $iv_kw_dir/keyword.txt ]; then
    echo "You can provide your own keywords in keyword.txt in the following format"
    echo "<word1>"
    echo "<word2>"
    echo "<word3>"
    echo "Now we use the template keyword for a quick start"
    cp ./conf/ivkwlist.txt $iv_kw_dir/keyword.txt
    cp ./conf/oovkwlist.txt $oov_kw_dir/keyword.txt
fi

if [ ! -f $iv_kw_dir/.kwlist.done ]; then
    ./local/prepare_kwlist.sh $iv_kw_dir
    ./local/prepare_kwlist.sh $oov_kw_dir
    touch $iv_kw_dir/.kwlist.done
fi

# Create RTTM file
if [ ! -f $iv_kw_dir/.rttm.done ]; then
    ./local/create_rttm.sh dev10h.seg
    cp exp_dev10h.seg/tri5_ali/rttm $oov_kw_dir/rttm
    cp exp_dev10h.seg/tri5_ali/rttm $iv_kw_dir/rttm
    touch $iv_kw_dir/.rttm.done
fi

# Setup KWS
if [ ! -f $iv_kw_dir/.prep.done ]; then
    ./local/kws_data_prep.sh $lang $in_dir $iv_kw_dir
    ./local/kws_data_prep.sh $lang $in_dir $oov_kw_dir
    touch $iv_kw_dir/.prep.done
fi

if [ ! -f $iv_kw_dir/.setup.done ]; then
#    ./local/kws_setup.sh \
#    --case_insensitive false\
#    --rttm-file $kw_dir/rttm \
#    $kw_dir/ecf.xml $kw_dir/keyword.txt $lang $in_dir
    touch $iv_kw_dir/.setup.done
fi

echo "Congrats!Data Preparation Finished"
