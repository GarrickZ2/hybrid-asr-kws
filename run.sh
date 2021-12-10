#!/usr/bin/env bash

. ./conf/common_vars.sh || exit 1;
. ./conf/lang.conf || exit 1;
. ./cmd.sh
. ./path.sh

nj=35
decode_nj=30
none_nn=true


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
if [ ! -f data/local/dict_nosp/.done ]; then
	echo ---------------------------------------------------------------------
	echo " Prepare the dictionary on " `date`
	echo ---------------------------------------------------------------------
    local/prepare_dict.sh
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
if [ ! -f data/local/lm_nosp/.done ]; then
	echo ---------------------------------------------------------------------
	echo " Prepare the lang directory on " `date`
	echo ---------------------------------------------------------------------
	local/ted_download_lm.sh
	# local/ted_train_lm.sh
	touch data/local/lm_nosp/.done
	echo ---------------------------------------------------------------------
	echo " Finish Preparing the lang directory on " `date`
	echo ---------------------------------------------------------------------
else
	echo "Have finish language model training , won't do it agaion."
	echo "If you want to do it again, remove the .done file under data/local/lm_nosp folder"
	echo
fi

if [ ! -f data/local/lm_nosp/.lms.done ]; then
	echo ---------------------------------------------------------------------
	echo " Prepare the lms on " `date`
	echo ---------------------------------------------------------------------
    local/format_lms.sh
	touch data/local/lm_nosp/.lms.done
	echo ---------------------------------------------------------------------
	echo " Finish Preparing lms on " `date`
	echo ---------------------------------------------------------------------
else
	echo "Have finish lms, won't do it agaion."
	echo "If you want to do it again, remove the .lms.done file under data/local/lm_nosp folder"
	echo
fi

# Feature extraction might be useless
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
else
	echo "Have finish the full triphone training, won't do it agaion."
	echo "If you want to do it again, remove the .done file under exp/tri3 folder"
	echo
fi

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
else
	echo "Have finish lda_mllt training, won't do it agaion."
	echo "If you want to do it again, remove the .done file under exp/tri4 folder"
	echo
fi

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

################################################################################
# Ready to start SGMM training
################################################################################
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

################################################################################
# Ready to start discriminative SGMM training
################################################################################

if [ $stage -le 17 ]; then
  echo ---------------------------------------------------------------------
  echo "Starting exp/sgmm5_ali on" `date`
  echo ---------------------------------------------------------------------
  steps/align_sgmm2.sh \
    --nj $train_nj --cmd "$train_cmd" --transform-dir exp/tri5_ali \
    --use-graphs true --use-gselect true \
    data/train data/lang_nosp exp/sgmm5 exp/sgmm5_ali
  touch exp/sgmm5_ali/.done
fi

if [ $stage -le 18 ]; then
  echo ---------------------------------------------------------------------
  echo "Starting exp/sgmm5_denlats on" `date`
  echo ---------------------------------------------------------------------
  steps/make_denlats_sgmm2.sh \
    --nj $train_nj --sub-split $train_nj "${sgmm_denlats_extra_opts[@]}" \
    --beam 10.0 --lattice-beam 6 --cmd "$decode_cmd" --transform-dir exp/tri5_ali \
    data/train data/lang_nosp exp/sgmm5_ali exp/sgmm5_denlats
  touch exp/sgmm5_denlats/.done
fi

if [ $stage -le 19 ]; then
  echo ---------------------------------------------------------------------
  echo "Starting exp/sgmm5_mmi_b0.1 on" `date`
  echo ---------------------------------------------------------------------
  steps/train_mmi_sgmm2.sh \
    --cmd "$train_cmd" "${sgmm_mmi_extra_opts[@]}" \
    --drop-frames true --transform-dir exp/tri5_ali --boost 0.1 \
    data/train data/lang_nosp exp/sgmm5_ali exp/sgmm5_denlats \
    exp/sgmm5_mmi_b0.1
  touch exp/sgmm5_mmi_b0.1/.done
fi

echo ---------------------------------------------------------------------
echo "Finished successfully on" `date`
echo ---------------------------------------------------------------------

exit 0
