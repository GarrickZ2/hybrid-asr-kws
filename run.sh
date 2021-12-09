#!/usr/bin/env bash

echo "Loading Config"
. ./conf/common_vars.sh || exit 1;
. ./conf/lang.conf || exit 1;
. ./cmd.sh
. ./path.sh
echo "Finish Loading Config"

tri5_only=false
sgmm5_only=true
data_only=false

stage=$1
nj=35
decode_nj=30


# download the training data
if [ $stage -le 0 ]; then
    echo "===============Start to download necessary data===================="
    local/download_data.sh
    echo "===============Finish download and extract data===================="
fi

# Split speakers up into 3-minute chunks.
if [ $stage -le 1 ]; then
    echo "===============Data Preparation===================="
    local/prepare_data.sh
    for dset in dev test train; do
        utils/data/modify_speaker_info.sh --seconds-per-spk-max 180 data/${dset}.orig data/${dset}
    done
    echo "===============Finished Preparated===================="
fi

# Prepare the dictionary
if [ $stage -le 2 ]; then
    echo "===============Produce the Dict===================="
    ./utils/subset_data_dir.sh --per-spk data/train 5 data/train_split
    mv data/train data/train_orig
    mv data/train_split data/train
    local/prepare_dict.sh
    echo "===============Finished Dict Pre===================="
fi

# Prepare the language file 
if [ $stage -le 3 ]; then
    echo "===============Produce the Lang===================="
    utils/prepare_lang.sh data/local/dict_nosp \
    "<unk>" data/local/lang_nosp data/lang_nosp
    echo "===============Finshed the Lang===================="
fi

# may be useless put here for later use
if [ $stage -le 4 ]; then
    echo "===============Downlaod the LM===================="
    # Download the pre-built LMs from kaldi-asr.org instead of building them
    # locally.
    local/ted_download_lm.sh
    # Uncomment this script to build the language models instead of
    # downloading them from kaldi-asr.org.
    # local/ted_train_lm.sh
    # local/train_lms_srilm.sh --dev-text data/dev/text \
    # --train-text data/train/text data data/local/srilm 
    echo "===============Finished the LM===================="
fi

# may be useless put here for later use
if [ $stage -le 5 ]; then
    echo "===============Format the LMS===================="
    local/format_lms.sh
    # local/arpa2G.sh data/local/srilm/lm.gz data/lang_nosp data/lang_nosp
    echo "===============Finsihed the LMS===================="
fi

# Feature extraction might be useless
if [ $stage -le 6 ]; then
    for set in test dev train; do
        echo "===============Start Extract $set Feature===================="
        if $use_pitch; then
			steps/make_plp_pitch.sh --cmd "$train_cmd" --nj $train_nj data/$set exp/make_plp_pitch/$set plp/$set
		else
 		   steps/make_plp.sh --cmd "$train_cmd" --nj $train_nj data/$set exp/$set/$set plp/$set
 		fi
  		utils/fix_data_dir.sh data/$set
  		steps/compute_cmvn_stats.sh data/$set exp/make_plp/$set plp/$set
  		utils/fix_data_dir.sh data/$set
        echo "===============Finish Extract $set Feature===================="
    done
fi

# Now we have 212 hours of training data.
# Well create a subset with 10k short segments to make flat-start training easier:
# Let's create 3 subset would be ok
# Necessary for tri1 training
if [ $stage -le 7 ]; then
    echo "===============Start Create 5k Subset Data===================="
    utils/subset_data_dir.sh --shortest data/train 5000 data/train_5kshort
    utils/data/remove_dup_utts.sh 10 data/train_5kshort data/train_5kshort_nodup
    echo "===============Finish Create 5k Subset Data===================="

    echo "===============Start Create 10k Subset Data===================="
    utils/subset_data_dir.sh --shortest data/train 10000 data/train_10kshort
    utils/data/remove_dup_utts.sh 10 data/train_10kshort data/train_10kshort_nodup
    echo "===============Finish Create 10k Subset Data===================="

    echo "===============Start Create 20k Subset Data===================="
    utils/subset_data_dir.sh --shortest data/train 20000 data/train_20kshort
    utils/data/remove_dup_utts.sh 10 data/train_20kshort data/train_20kshort_nodup
    echo "===============Finish Create 20k Subset Data===================="
fi

# Train
if [ $stage -le 8 ]; then
    echo ---------------------------------------------------------------------
    echo "Starting (small) monophone training in exp/mono on" `date`
    echo ---------------------------------------------------------------------
    steps/train_mono.sh --boost-silence $boost_sil --nj 20 --cmd "$train_cmd" \
        data/train_5kshort_nodup data/lang_nosp exp/mono
fi


if [ $stage -le 9 ]; then
  echo ---------------------------------------------------------------------
  echo "Starting (small) triphone training in exp/tri1 on" `date`
  echo ---------------------------------------------------------------------
  steps/align_si.sh \
    --boost-silence $boost_sil --nj 20 --cmd "$train_cmd" \
    data/train_10kshort_nodup data/lang_nosp exp/mono exp/mono_ali_sub2
  steps/train_deltas.sh \
    --boost-silence $boost_sil --cmd "$train_cmd" $numLeavesTri1 $numGaussTri1 \
    data/train_10kshort_nodup data/lang_nosp exp/mono_ali_sub2 exp/tri1
fi
# --cmd "$train_cmd" 2500 30000 \

if [ $stage -le 10 ]; then
  echo ---------------------------------------------------------------------
  echo "Starting (medium) triphone training in exp/tri2 on" `date`
  echo ---------------------------------------------------------------------
  steps/align_si.sh \
    --boost-silence $boost_sil --nj 24 --cmd "$train_cmd" \
    data/train_20kshort_nodup data/lang_nosp exp/tri1 exp/tri1_ali_sub3
  steps/train_deltas.sh \
    --cmd "$train_cmd" $numLeavesTri2 $numGaussTri2 \
    data/train_20kshort_nodup data/lang_nosp exp/tri1_ali_sub3 exp/tri2
fi
# --cmd "$train_cmd" 2500 30000 \

if [ $stage -le 11 ]; then
  echo ---------------------------------------------------------------------
  echo "Starting (full) triphone training in exp/tri3 on" `date`
  echo ---------------------------------------------------------------------
  steps/align_si.sh \
    --boost-silence $boost_sil --nj $train_nj --cmd "$train_cmd" \
    data/train data/lang_nosp exp/tri2 exp/tri2_ali
  steps/train_deltas.sh \
    --boost-silence $boost_sil --cmd "$train_cmd" \
    $numLeavesTri3 $numGaussTri3 data/train data/lang_nosp exp/tri2_ali exp/tri3
fi

# This will be used in the next segmentation
if [ $stage -le 12 ]; then
  echo ---------------------------------------------------------------------
  echo "Starting (lda_mllt) triphone training in exp/tri4 on" `date`
  echo ---------------------------------------------------------------------
  steps/align_si.sh \
    --boost-silence $boost_sil --nj $train_nj --cmd "$train_cmd" \
    data/train data/lang_nosp exp/tri3 exp/tri3_ali
  steps/train_lda_mllt.sh \
    --boost-silence $boost_sil --cmd "$train_cmd" \
    $numLeavesMLLT $numGaussMLLT data/train data/lang_nosp exp/tri3_ali exp/tri4
fi

if [ $stage -le 13 ]; then
  echo ---------------------------------------------------------------------
  echo "Starting (SAT) triphone training in exp/tri5 on" `date`
  echo ---------------------------------------------------------------------
  steps/align_si.sh \
    --boost-silence $boost_sil --nj $train_nj --cmd "$train_cmd" \
    data/train data/lang_nosp exp/tri4 exp/tri4_ali
  steps/train_sat.sh \
    --boost-silence $boost_sil --cmd "$train_cmd" \
    $numLeavesSAT $numGaussSAT data/train data/lang_nosp exp/tri4_ali exp/tri5
fi

################################################################################
# Ready to start SGMM training
################################################################################
if [ $stage -le 14 ]; then
  echo ---------------------------------------------------------------------
  echo "Starting exp/tri5_ali on" `date`
  echo ---------------------------------------------------------------------
  steps/align_fmllr.sh \
    --boost-silence $boost_sil --nj $train_nj --cmd "$train_cmd" \
    data/train data/lang_nosp exp/tri5 exp/tri5_ali
fi

if $tri5_only ; then
  echo "Exiting after stage TRI5, as requested. "
  echo "Everything went fine. Done"
  exit 0;
fi

if [ $stage -le 15 ]; then
  echo ---------------------------------------------------------------------
  echo "Starting exp/ubm5 on" `date`
  echo ---------------------------------------------------------------------
  steps/train_ubm.sh \
    --cmd "$train_cmd" $numGaussUBM \
    data/train data/lang_nosp exp/tri5_ali exp/ubm5
fi

if [ $stage -le 16 ]; then
  echo ---------------------------------------------------------------------
  echo "Starting exp/sgmm5 on" `date`
  echo ---------------------------------------------------------------------
  steps/train_sgmm2.sh \
    --cmd "$train_cmd" $numLeavesSGMM $numGaussSGMM \
    data/train data/lang_nosp exp/tri5_ali exp/ubm5/final.ubm exp/sgmm5
  #steps/train_sgmm2_group.sh \
  #  --cmd "$train_cmd" "${sgmm_group_extra_opts[@]-}" $numLeavesSGMM $numGaussSGMM \
  #  data/train data/lang exp/tri5_ali exp/ubm5/final.ubm exp/sgmm5
fi

if $sgmm5_only ; then
  echo "Exiting after stage SGMM5, as requested. "
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
