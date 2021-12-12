#!/usr/bin/env bash

echo "Loading Config"
. ./cmd.sh
. ./path.sh
. ./conf/common_vars.sh || exit 1;
. ./conf/lang.conf || exit 1;
echo "Finish Loading Config"

if [ $# != 2 ]; then
    echo "Usage: prepare_kws_data.sh <data-dir> <lang-dir>"
    echo "e.g.: prepare_kws_data.sh data/dev10h.seg data/lang_nosp"
    exit 0
fi

in_dir=`utils/make_absolute.sh $1`
lang=`utils/make_absolute.sh $2`

kw_dir=$in_dir/kws
iv_kw_dir=$in_dir/iv_kws
oov_kw_dir=$in_dir/oov_kws

dir_id=${in_dir##*/}
exp_dir=exp_$dir_id

mkdir -p $kw_dir
mkdir -p $iv_kw_dir
mkdir -p $oov_kw_dir

# Create the ECF file
if [ ! -f $iv_kw_dir/.ecf.done ]; then
    ./local/create_ecf_file.sh $in_dir/wav.scp $kw_dir/ecf.xml
    cp $kw_dir/ecf.xml $iv_kw_dir/ecf.xml
    cp $iv_kw_dir/ecf.xml $oov_kw_dir/ecf.xml
    touch $iv_kw_dir/.ecf.done
else
    echo "ECF.XML has been created, won't do it again"
    echo "Revome $iv_kw_dir/.ecf.done to do it again"
    echo
fi

# Create the kwlist
if [ ! -f $iv_kw_dir/keyword.txt ]; then
    kwlist_dir="conf"
    if [ -f $in_dir/ivkwlist.txt ]; then
        kwlist_dir=$in_dir
    else
        echo "You can provide your own keywords in keyword.txt in the following format"
        echo "<word1>"
        echo "<word2>"
        echo "<word3>"
        echo "Now we use the template keyword for a quick start"
    fi
    cp $kwlist_dir/ivkwlist.txt $iv_kw_dir/keyword.txt
    cp $kwlist_dir/oovkwlist.txt $oov_kw_dir/keyword.txt
	cat $iv_kw_dir/keyword.txt > $kw_dir/keyword.txt
	cat $oov_kw_dir/keyword.txt >> $kw_dir/keyword.txt
    unset kwlist_dir
else
    echo "Keywords has been prepared, won't do it again"
    echo "Remove the keyword.txt within $iv_kw_dir to do it again"
    echo
fi

if [ ! -f $iv_kw_dir/.kwlist.done ]; then
    ./local/prepare_kwlist.sh $iv_kw_dir
    ./local/prepare_kwlist.sh $oov_kw_dir
	./local/prepare_kwlist.sh $kw_dir
    touch $iv_kw_dir/.kwlist.done
else
    echo "KWLIST has been created, won't do it again"
    echo "Remove $iv_kw_dir/.kwlist.done to do it again"
    echo
fi

# Create RTTM file
if [ ! -f $iv_kw_dir/.rttm.done ]; then
    ./local/create_rttm.sh $dir_id
    cp $exp_dir/tri5_ali/rttm $oov_kw_dir/rttm
    cp $exp_dir/tri5_ali/rttm $iv_kw_dir/rttm
    cp $exp_dir/tri5_ali/rttm $kw_dir/rttm
    touch $iv_kw_dir/.rttm.done
else
    echo "Has created RTTM file, won't do it again"
    echo "Please remove $iv_kw_dir/.rttm.done and $exp_dir"
    echo
fi

# Create hitlist
if [ ! -f $iv_kw_dir/.hitlist.done ]; then
	cat $in_dir/utt2dur | awk 'BEGIN{i=1}; {print $1, i; i+=1;}' > $iv_kw_dir/utt.map
	cat $in_dir/wav.scp | awk 'BEGIN{i=1}; {print $1, i; i+=1;}' > $iv_kw_dir/wav.map
	cp $lang/words.txt $iv_kw_dir/words.txt
	cat $iv_kw_dir/keyword.txt | \
		local/kws/keywords_to_indices.pl --map-oov 0  $iv_kw_dir/words.txt | \
		sort -u > $iv_kw_dir/keywords.int
    ./local/kws/create_hitlist.sh $in_dir $lang data/local/lang_nosp $exp_dir/tri5_ali $iv_kw_dir


	cat $in_dir/utt2dur | awk 'BEGIN{i=1}; {print $1, i; i+=1;}' > $kw_dir/utt.map
	cat $in_dir/wav.scp | awk 'BEGIN{i=1}; {print $1, i; i+=1;}' > $kw_dir/wav.map
	cp $lang/words.txt $kw_dir/words.txt
	cat $kw_dir/keyword.txt | \
		local/kws/keywords_to_indices.pl --map-oov 0  $kw_dir/words.txt | \
		sort -u > $kw_dir/keywords.int
    ./local/kws/create_hitlist.sh $in_dir $lang data/local/lang_nosp exp_dev10h.seg/tri5_ali $kw_dir

    touch $iv_kw_dir/.hitlist.done
else
    echo "Has created hitlist file, won't do it again"
    echo "Please remove $iv_kw_dir/.hitlist.done"
    echo
fi

# Setup KWS
if [ ! -f $iv_kw_dir/.prep.done ]; then
    ./local/kws_data_prep.sh $lang $in_dir $iv_kw_dir
    ./local/kws_data_prep.sh $lang $in_dir $oov_kw_dir
    ./local/kws_data_prep.sh $lang $in_dir $kw_dir
    touch $iv_kw_dir/.prep.done
else
    echo "Has finished keyword generation"
    echo "Please remove the $iv_kw_dir/.prep.done to do it again"
    echo
fi

if [ ! -f $iv_kw_dir/.setup.done ]; then
#    ./local/kws_setup.sh \
#    --case_insensitive false\
#    --rttm-file $kw_dir/rttm \
#    $kw_dir/ecf.xml $kw_dir/keyword.txt $lang $in_dir
    touch $iv_kw_dir/.setup.done
fi

echo "Congrats!Data Preparation Finished"
