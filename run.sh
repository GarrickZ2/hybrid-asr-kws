#!/usr/bin/env bash

# run.sh : perform the training process for our model.
# Nearly every line of this script has been touched by zz2888, some are new some are modified.
# I have also indicated the new block by comment with zz2888

. ./conf/common_vars.sh || exit 1;
. ./conf/lang.conf || exit 1;
. ./cmd.sh
. ./path.sh

nj=35
decode_nj=30
none_nn=true
limited_language=true
limited_lexicon=true
hybrid_asr=true
with_gpu=false
train_stage=-10
decode=false # This option is used to get the performance for middle layer's model
			 # It really slowing down the training process, try not to turn it on
			 # For the real decoding, please run run_decode.sh

. utils/parse_options.sh

# download the training data
if [ ! -f db/.done ]; then
	echo ---------------------------------------------------------------------
	echo " Start to download the data on " `date`
	echo ---------------------------------------------------------------------
	local/download_data.sh
	touch db/.done
	echo ---------------------------------------------------------------------
	echo " Finsh download the data on " `date`
	echo ---------------------------------------------------------------------
else
	echo "Have download the data, won't do it again."
	echo "If you want to re-download the data, please remove the db/ folder"
	echo
fi

# Split speakers up into 3-minute chunks.
if [ ! -f data/.prepare.done ]; then
	echo ---------------------------------------------------------------------
	echo " Prepare the data on " `date`
	echo ---------------------------------------------------------------------
	local/prepare_data.sh
	for dset in dev test train; do
		utils/data/modify_speaker_info.sh --seconds-per-spk-max 180 data/${dset}.orig data/${dset}
	done
	touch data/.prepare.done
	echo ---------------------------------------------------------------------
	echo " Finish the data preparation on " `date`
	echo ---------------------------------------------------------------------
else
	echo "Have modify the spekaer information and split data, won't do it agaion."
	echo "If you want to do it again, remove the .prepare.done file under data folder"
	echo
fi

# Prepare the dictionary
# Block written by zz2888: adding limited lexicon and limited language
if [ ! -f data/local/dict_nosp/.done ]; then
	echo ---------------------------------------------------------------------
	echo " Prepare the dictionary, with limited_langauge("$limited_language") on " `date`
	echo ---------------------------------------------------------------------
	if $limited_language ; then
		./utils/subset_data_dir.sh --per-spk data/train 5 data/train_split
		mv data/train data/train_orig
		mv data/train_split data/train
		local/prepare_dict.sh
		if $limited_lexicon ; then
			echo ---------------------------------------------------------------------
			echo " Create the limited lexicon on " `date`
			echo ---------------------------------------------------------------------
			python local/make_lexicon_subset.py data/train/text data/local/dict_nosp/lexicon.txt > data/local/limited_dict
			rm -rf data/local/dict_nosp
			local/prepare_dict.sh --srcdict data/local/limited_dict
		fi
	else
		local/prepare_dict.sh
	fi
	echo ---------------------------------------------------------------------
	echo " Finish Preparing the dictionary on " `date`
	echo ---------------------------------------------------------------------
	touch data/local/dict_nosp/.done
else
	echo "Have finish dictionary preparation, won't do it agaion."
	echo "If you want to do it again, remove the .done file under data/local/dict_nosp folder"
	echo
fi

# Prepare the language file 
if [ ! -f data/dict_nosp/.done ]; then
	echo ---------------------------------------------------------------------
	echo " Prepare the lang directory on " `date`
	echo ---------------------------------------------------------------------
	utils/prepare_lang.sh data/local/dict_nosp \
		"<unk>" data/local/lang_nosp data/lang_nosp

	touch data/dict_nosp/.done
	echo ---------------------------------------------------------------------
	echo " Finish Preparing the lang directory on " `date`
	echo ---------------------------------------------------------------------
else
	echo "Have finish lang dir preparation, won't do it agaion."
	echo "If you want to do it again, remove the .done file under data/dict_nosp folder"
	echo
fi

# may be useless put here for later use
if [ ! -f data/local/local_lm/.done ]; then
	echo ---------------------------------------------------------------------
	echo " Prepare the lang directory on " `date`
	echo ---------------------------------------------------------------------
	local/ted_download_lm.sh
	# local/ted_train_lm.sh
	touch data/local/local_lm/.done
	echo ---------------------------------------------------------------------
	echo " Finish Preparing the lang directory on " `date`
	echo ---------------------------------------------------------------------
else
	echo "Have finish language model training , won't do it agaion."
	echo "If you want to do it again, remove the .done file under data/local/lm_nosp folder"
	echo
fi

if [ ! -f data/local/local_lm/.lms.done ]; then
	echo ---------------------------------------------------------------------
	echo " Prepare the lms on " `date`
	echo ---------------------------------------------------------------------
    local/format_lms.sh
	touch data/local/local_lm/.lms.done
	echo ---------------------------------------------------------------------
	echo " Finish Preparing lms on " `date`
	echo ---------------------------------------------------------------------
else
	echo "Have finish lms, won't do it agaion."
	echo "If you want to do it again, remove the .lms.done file under data/local/lm_nosp folder"
	echo
fi

# Block written by zz2888: add hybrid asr model
if $hybrid_asr ; then
	echo ---------------------------------------------------------------------
	echo " Start to prepare data for Hybrid ASR on " `date`
	echo ---------------------------------------------------------------------
	g2p=data/local/g2p
	if [ ! -f $g2p/.done ]; then
		mkdir -p $g2p
		echo ---------------------------------------------------------------------
		echo " Start to Training G2P Model-1 on " `date`
		echo ---------------------------------------------------------------------
		python3 $SEQUITUR/bin/g2p.py --train data/local/dict_nosp/lexicon.txt --devel 5% --write-model $g2p/model-1 > $g2p/log-1

		echo ---------------------------------------------------------------------
		echo " Start to Training G2P Model-2 on " `date`
		echo ---------------------------------------------------------------------
		python3 $SEQUITUR/g2p.py --model $g2p/model-1 --ramp-up --train data/local/dict_nosp/lexicon.txt --devel 5% --write-model $g2p/model-2 > $g2p/log-2

		echo ---------------------------------------------------------------------
		echo " Start to Training G2P Model-3 on " `date`
		echo ---------------------------------------------------------------------
		python3 $SEQUITUR/g2p.py --model $g2p/model-2 --ramp-up --train data/local/dict_nosp/lexicon.txt --devel 5% --write-model $g2p/model-3 > $g2p/log-3

		echo ---------------------------------------------------------------------
		echo " Start to Training G2P Model-4 on " `date`
		echo ---------------------------------------------------------------------
		python3 $SEQUITUR/g2p.py --model $g2p/model-3 --ramp-up --train data/local/dict_nosp/lexicon.txt --devel 5% --write-model $g2p/model-4 > $g2p/log-4

		echo ---------------------------------------------------------------------
		echo " Start to Training G2P Model-5 on " `date`
		echo ---------------------------------------------------------------------
		python3 $SEQUITUR/g2p.py --model $g2p/model-4 --ramp-up --train data/local/dict_nosp/lexicon.txt --devel 5% --write-model $g2p/model-5 > $g2p/log-5

		touch $g2p/.done
	else
		echo "Have finish training G2P model, won't do it agaion."
		echo "If you want to do it again, remove the .done file under data/local/g2p folder"
		echo
	fi

	if [ ! -f data/.hybrid.dict.done ]; then
		echo ---------------------------------------------------------------------
		echo " Prepare dictionary and lang file with oovs on " `date`
		echo ---------------------------------------------------------------------
		local/prepare_dict_ngram_oovs.sh data/lang_nosp data/local/g2p data/local/dict_hybrid/
		utils/prepare_lang.sh data/local/dict_hybrid/ "<unk>" data/local/lang_hybrid data/lang_hybrid

		touch data/.hybrid.dict.done
	else
		echo "Have finished dictionary prepartion, won't do it agaion."
		echo "If you want to do it again, remove the .hybrid.dict.done file under data/ folder"
		echo
	fi

	if [ ! -f data/.hybrid.lm.done ]; then
		echo ---------------------------------------------------------------------
		echo " Prepare hybrid dictionary and lang file on " `date`
		echo ---------------------------------------------------------------------
		./local/prepare_lang_wrdphn.sh data/local/dict_hybrid/ "<unk>" data/local/lang_wrdphn_hybrid data/lang_wrd_hybrid/ data/lang_phn_hybrid
		cat data/local/dict_hybrid/lexicon_raw_nosil.txt | sed 's/[0-9]*//g' | awk '{for (i=2; i<=NF; i++) printf "PHN_"$i " "; print "\n"}' | grep -v '^\s*$' > ./data/lang_phn_hybrid/lm_train_text.txt
		ngram-count -text data/lang_phn_hybrid/lm_train_text.txt -order 3 -wbdiscount -interpolate -lm - > data/lang_phn_hybrid/phn.3gram.lm

		echo ---------------------------------------------------------------------
		echo " Filter OOVs from word LM on" `date`
		echo ---------------------------------------------------------------------
		mkdir -p data/local/local_lm/data/hybrid
		cat data/local/dict_hybrid/lexicon.txt | awk '{print $1}' > vocab_hybrid.txt
		change-lm-vocab -vocab vocab_hybrid.txt -lm data/local/local_lm/data/arpa/4gram_big.arpa.gz -write-vocab lm_vocab_hybrid.txt -write-lm data/local/local_lm/data/hybrid/word.3gram.lm -subset -prune-lowprobs -unk -map-unk "<unk>" -order 3

		touch data/.hybrid.lm.done
	else
		echo "Have finished hybrid language modle prep, won't do it agaion."
		echo "If you want to do it again, remove the .hybrid.lm.done file under data/ folder"
		echo
	fi

	baseline_lang=lang_hybrid
	hybrid_lang=data/lang_hybrid_transform
	if [ ! -f data/.hybrid.lms.done ]; then
		echo ---------------------------------------------------------------------
		echo " Create new combined lang folder on" `date`
		echo ---------------------------------------------------------------------
		./local/make_hybrid_fst_3gram.sh 0 1 0 data/lang_phn_hybrid data/lang_wrd_hybrid data/test_hybrid
		mkdir -p $hybrid_lang
		cp -r data/$baseline_lang/* $hybrid_lang/
		fstcompile --acceptor=false --isymbols=$hybrid_lang/words.txt --osymbols=$hybrid_lang/words.txt < data/test_hybrid/G_WRDPHNm_final.txt | fstarcsort --sort_type=ilabel > $hybrid_lang/G.fst
		mv data/local/lang_nosp data/local/lang_nosp_orig
		mv data/lang_nosp data/lang_nosp_orig
		mv data/lang_hybrid_transform data/lang_nosp
		mv data/local/lang_wrdphn_hybrid data/local/lang_nosp

		touch data/.hybrid.lms.done
	else
		echo "Have finished hybrid lang folder prep, won't do it agaion."
		echo "If you want to do it again, remove the .hybrid.lms.done file under data/ folder"
		echo
	fi
fi


# Feature extraction 
if [ ! -f data/.feats.done ]; then
	for set in test dev train; do
		echo ---------------------------------------------------------------------
		echo "Extra the features for dataset $set on " `date`
		echo ---------------------------------------------------------------------
		if $use_pitch; then
			steps/make_plp_pitch.sh --cmd "$train_cmd" --nj $train_nj data/$set exp/make_plp_pitch/$set plp/$set
		else
			steps/make_plp.sh --cmd "$train_cmd" --nj $train_nj data/$set exp/$set/$set plp/$set
		fi
		utils/fix_data_dir.sh data/$set
		steps/compute_cmvn_stats.sh data/$set exp/make_plp/$set plp/$set
		utils/fix_data_dir.sh data/$set
		echo ---------------------------------------------------------------------
		echo "Finsh the features for dataset $set on " `date`
		echo ---------------------------------------------------------------------
    done
	touch data/.feats.done
else
	echo "Have finish feature extraction, won't do it agaion."
	echo "If you want to do it again, remove the .feats.done file under data/ folder"
	echo
fi

# Block written by zz2888: add sub-directory
# Now we have 212 hours of training data.
# Well create a subset with 10k short segments to make flat-start training easier:
# Let's create 3 subset would be ok
# Necessary for tri1 training
if [ ! -f data/.sub.done ]; then
	echo ---------------------------------------------------------------------
	echo "Split 5k sub training set on " `date`
	echo ---------------------------------------------------------------------
	utils/subset_data_dir.sh --shortest data/train 5000 data/train_5kshort
	utils/data/remove_dup_utts.sh 10 data/train_5kshort data/train_5kshort_nodup

	echo ---------------------------------------------------------------------
	echo "Split 10k sub training set on " `date`
	echo ---------------------------------------------------------------------
	utils/subset_data_dir.sh --shortest data/train 10000 data/train_10kshort
	utils/data/remove_dup_utts.sh 10 data/train_10kshort data/train_10kshort_nodup

	echo ---------------------------------------------------------------------
	echo "Split 20k sub training set on " `date`
	echo ---------------------------------------------------------------------
	utils/subset_data_dir.sh --shortest data/train 20000 data/train_20kshort
	utils/data/remove_dup_utts.sh 10 data/train_20kshort data/train_20kshort_nodup

	touch data/.sub.done
else
	echo "Have finish training data split , won't do it agaion."
	echo "If you want to do it again, remove the .sub.done file under data/ folder"
	echo
fi

# Train
if [ ! -f exp/mono/.done ]; then
	echo ---------------------------------------------------------------------
	echo "Starting small monophone training in exp/mono on" `date`
	echo ---------------------------------------------------------------------
	steps/train_mono.sh --boost-silence $boost_sil --nj 20 --cmd "$train_cmd" \
		data/train_5kshort_nodup data/lang_nosp exp/mono
	touch exp/mono/.done
else
	echo "Have finish tmonophone training, won't do it agaion."
	echo "If you want to do it again, remove the .done file under exp/mono folder"
	echo
fi

# Block written by zz2888: sub-directory train1
if [ ! -f exp/tri1/.done ]; then
	echo ---------------------------------------------------------------------
	echo "Starting (small) triphone training in exp/tri1 on" `date`
	echo ---------------------------------------------------------------------
	steps/align_si.sh \
		--boost-silence $boost_sil --nj 20 --cmd "$train_cmd" \
		data/train_10kshort_nodup data/lang_nosp exp/mono exp/mono_ali_sub2
	steps/train_deltas.sh \
		--boost-silence $boost_sil --cmd "$train_cmd" $numLeavesTri1 $numGaussTri1 \
		data/train_10kshort_nodup data/lang_nosp exp/mono_ali_sub2 exp/tri1
	
	touch exp/tri1/.done
else
	echo "Have finish samll triphone training, won't do it agaion."
	echo "If you want to do it again, remove the .done file under exp/tri1 folder"
	echo
fi

# Block written by zz2888: sub-directory train2
if [ ! -f exp/tri2/.done ]; then
	echo ---------------------------------------------------------------------
	echo "Starting (medium) triphone training in exp/tri2 on" `date`
	echo ---------------------------------------------------------------------
	steps/align_si.sh \
		--boost-silence $boost_sil --nj 24 --cmd "$train_cmd" \
		data/train_20kshort_nodup data/lang_nosp exp/tri1 exp/tri1_ali_sub3
	steps/train_deltas.sh \
		--cmd "$train_cmd" $numLeavesTri2 $numGaussTri2 \
		data/train_20kshort_nodup data/lang_nosp exp/tri1_ali_sub3 exp/tri2
	touch exp/tri2/.done
else
	echo "Have finish the medium triphone training, won't do it agaion."
	echo "If you want to do it again, remove the .done file under exp/tri2 folder"
	echo
fi
# --cmd "$train_cmd" 2500 30000 \

# Block written by zz2888: sub-directory train3
if [ ! -f exp/tri3/.done ]; then
	echo ---------------------------------------------------------------------
	echo "Starting (full) triphone training in exp/tri3 on" `date`
	echo ---------------------------------------------------------------------
	steps/align_si.sh \
		--boost-silence $boost_sil --nj $train_nj --cmd "$train_cmd" \
		data/train data/lang_nosp exp/tri2 exp/tri2_ali
	steps/train_deltas.sh \
		--boost-silence $boost_sil --cmd "$train_cmd" \
		$numLeavesTri3 $numGaussTri3 data/train data/lang_nosp exp/tri2_ali exp/tri3
	touch exp/tri3/.done

	if [ $decode -a ! -f exp/tri3/.decode.done ]; then
  		utils/mkgraph.sh data/lang_nosp exp/tri3 exp/tri3/graph_nosp
		for dset in dev test; do
			steps/decode.sh --nj $decode_nj --cmd "$decode_cmd"  --num-threads 4 \
				exp/tri3/graph_nosp data/${dset} exp/tri3/decode_nosp_${dset}
			steps/lmrescore_const_arpa.sh  --cmd "$decode_cmd" data/lang_nosp data/lang_nosp_rescore \
				data/${dset} exp/tri3/decode_nosp_${dset} exp/tri3/decode_nosp_${dset}_rescore
		done
		touch exp/tri3/.decode.done
	fi
else
	echo "Have finish the full triphone training, won't do it agaion."
	echo "If you want to do it again, remove the .done file under exp/tri3 folder"
	echo
fi

# Block written by zz2888: Train lda_mllt model
# This will be used in the next segmentation
if [ ! -f exp/tri4/.done ]; then
	echo ---------------------------------------------------------------------
	echo "Starting (lda_mllt) triphone training in exp/tri4 on" `date`
	echo ---------------------------------------------------------------------
	steps/align_si.sh \
		--boost-silence $boost_sil --nj $train_nj --cmd "$train_cmd" \
		data/train data/lang_nosp exp/tri3 exp/tri3_ali
	steps/train_lda_mllt.sh \
		--boost-silence $boost_sil --cmd "$train_cmd" \
		$numLeavesMLLT $numGaussMLLT data/train data/lang_nosp exp/tri3_ali exp/tri4
	touch exp/tri4/.done

	if [ $decode -a ! -f exp/tri4/.decode.done ]; then
  		utils/mkgraph.sh data/lang_nosp exp/tri4 exp/tri4/graph_nosp
		for dset in dev test; do
			steps/decode.sh --nj $decode_nj --cmd "$decode_cmd"  --num-threads 4 \
				exp/tri4/graph_nosp data/${dset} exp/tri4/decode_nosp_${dset}
			steps/lmrescore_const_arpa.sh  --cmd "$decode_cmd" data/lang_nosp data/lang_nosp_rescore \
				data/${dset} exp/tri4/decode_nosp_${dset} exp/tri4/decode_nosp_${dset}_rescore
		done
		touch exp/tri4/.decode.done
	fi
else
	echo "Have finish lda_mllt training, won't do it agaion."
	echo "If you want to do it again, remove the .done file under exp/tri4 folder"
	echo
fi

# Block written by zz2888: Train SAT model based on LAD_MLLT
if [ ! -f exp/tri5/.done ]; then
	echo ---------------------------------------------------------------------
	echo "Starting (SAT) triphone training in exp/tri5 on" `date`
	echo ---------------------------------------------------------------------
	steps/align_si.sh \
		--boost-silence $boost_sil --nj $train_nj --cmd "$train_cmd" \
		data/train data/lang_nosp exp/tri4 exp/tri4_ali
	steps/train_sat.sh \
		--boost-silence $boost_sil --cmd "$train_cmd" \
		$numLeavesSAT $numGaussSAT data/train data/lang_nosp exp/tri4_ali exp/tri5
	touch exp/tri5/.done
else
	echo "Have finish SAT training, won't do it agaion."
	echo "If you want to do it again, remove the .done file under exp/tri5 folder"
	echo
fi

# Block Written by zz2888: Training fMLLR
if [ ! -f exp/tri5_ali/.done ]; then
	echo ---------------------------------------------------------------------
	echo "Starting exp/tri5_ali on" `date`
	echo ---------------------------------------------------------------------
	steps/align_fmllr.sh \
		--boost-silence $boost_sil --nj $train_nj --cmd "$train_cmd" \
		data/train data/lang_nosp exp/tri5 exp/tri5_ali
	touch exp/tri5_ali/.done
else
	echo "Have finish FMLLR training, won't do it agaion."
	echo "If you want to do it again, remove the .done file under exp/tri5_ali folder"
	echo
fi

if [ ! -f exp/ubm5/.done ]; then
	echo ---------------------------------------------------------------------
	echo "Starting exp/ubm5 on" `date`
	echo ---------------------------------------------------------------------
	steps/train_ubm.sh \
		--cmd "$train_cmd" $numGaussUBM \
		data/train data/lang_nosp exp/tri5_ali exp/ubm5
	touch exp/ubm5/.done
else
	echo "Have finish tmonophone training, won't do it agaion."
	echo "If you want to do it again, remove the .done file under exp/mono folder"
	echo
fi

# Block Written by zz2888: Training SGMM2
if [ ! -f exp/sgmm5/.done ]; then
	echo ---------------------------------------------------------------------
	echo "Starting exp/sgmm5 on" `date`
	echo ---------------------------------------------------------------------
	steps/train_sgmm2.sh \
		--cmd "$train_cmd" $numLeavesSGMM $numGaussSGMM \
		data/train data/lang_nosp exp/tri5_ali exp/ubm5/final.ubm exp/sgmm5
	touch exp/sgmm5/.done
else
	echo "Have finish sgmm5 training, won't do it agaion."
	echo "If you want to do it again, remove the .done file under exp/sgmm5 folder"
	echo
fi

if $none_nn; then
	echo "Exiting after stage SGMM5, as requested."
	echo "If you want to training neural network, run with option '--none_nn false'"
	echo "Everything went fine. Done"
	exit 0;
fi

# Block Written by zz2888: Training NNET
dir=exp/tri6_nnet
if [ ! -f $dir/.done ]; then
	echo ---------------------------------------------------------------------
	echo "Starting exp/tri6_nnet with_gpu($with_gpu) on" `date`
	echo ---------------------------------------------------------------------
	mkdir -p $dir
	if $with_gpu ; then
		steps/nnet2/train_pnorm_fast.sh \
			--stage $train_stage --mix-up $dnn_mixup \
			--initial-learning-rate $dnn_init_learning_rate \
			--final-learning-rate $dnn_final_learning_rate \
			--num-hidden-layers $dnn_num_hidden_layers \
			--pnorm-input-dim $dnn_input_dim \
			--pnorm-output-dim $dnn_output_dim \
			--cmd "$train_cmd" \
			data/train data/lang_nosp exp/tri5_ali $dir || exit 1
	else
		steps/nnet2/train_pnorm.sh \
			--stage $train_stage --mix-up $dnn_mixup \
			--initial-learning-rate $dnn_init_learning_rate \
			--final-learning-rate $dnn_final_learning_rate \
			--num-hidden-layers $dnn_num_hidden_layers \
			--pnorm-input-dim $dnn_input_dim \
			--pnorm-output-dim $dnn_output_dim \
			--cmd "$train_cmd" \
	    	data/train data/lang_nosp exp/tri5_ali $dir || exit 1
	fi
	touch $dir/.done
else
	echo "Have finished tri6_nnet training, won't do it again."
	echo "If you want to do it again, remove the .done file under exp/tri6_nnet folder"
	echo
fi

dir=exp/tri6b_nnet
if [ ! -f $dir/.done ]; then
	echo ---------------------------------------------------------------------
	echo "Starting exp/tri6b_nnet with_gpu($with_gpu) on" `date`
	echo ---------------------------------------------------------------------
	dnn_pnorm_input_dim=3000
	dnn_pnorm_output_dim=300
	dnn_init_learning_rate=0.004
	ensemble_size=4
	initial_beta=0.1
	final_beta=0.2
	steps/nnet2/train_pnorm_ensemble.sh \
		--stage $train_stage --mix-up $dnn_mixup \
		--initial-learning-rate $dnn_init_learning_rate \
		--final-learning-rate $dnn_final_learning_rate \
		--num-hidden-layers $dnn_num_hidden_layers \
		--pnorm-input-dim $dnn_pnorm_input_dim \
		--pnorm-output-dim $dnn_pnorm_output_dim \
		--cmd "$train_cmd" \
		--ensemble-size $ensemble_size --initial-beta $initial_beta --final-beta $final_beta \
		data/train data/lang_nosp exp/tri5_ali $dir || exit 1
	touch $dir/.done
else
	echo "Have finished tri6b_nnet training, won't do it again."
	echo "If you want to do it again, remove the .done file under exp/tri6b_nnet folder"
	echo
fi

echo ---------------------------------------------------------------------
echo "Finished successfully on" `date`
echo ---------------------------------------------------------------------

exit 0