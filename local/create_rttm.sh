#!/bin/bash

echo "Loading Config"
. ./conf/common_vars.sh || exit 1;
. ./conf/lang.conf || exit 1;
. ./cmd.sh
. ./path.sh
echo "Finish Loading Config"

dir=$1
nj=35
decode_nj=30

mkdir -p exp_$dir 
if [ ! -f exp_$dir/mono/.done  ]; then
    echo ---------------------------------------------------------------------
    echo "Starting (small) monophone training in exp/mono on" `date`
    echo ---------------------------------------------------------------------
    steps/train_mono.sh --boost-silence $boost_sil --nj 20 --cmd "$train_cmd" \
        data/$dir data/lang_nosp exp_$dir/mono
    touch exp_$dir/mono/.done
fi

if [ ! -f exp_$dir/tri1/.done  ]; then
  echo ---------------------------------------------------------------------
  echo "Starting (small) triphone training in exp/tri1 on" `date`
  echo ---------------------------------------------------------------------
  steps/align_si.sh \
    --boost-silence $boost_sil --nj 20 --cmd "$train_cmd" \
    data/$dir data/lang_nosp exp_$dir/mono exp_$dir/mono_ali_sub2
  steps/train_deltas.sh \
    --boost-silence $boost_sil --cmd "$train_cmd" $numLeavesTri1 $numGaussTri1 \
    data/$dir data/lang_nosp exp_$dir/mono_ali_sub2 exp_$dir/tri1
    touch exp_$dir/tri1/.done
fi
# --cmd "$train_cmd" 2500 30000 \

if [ ! -f exp_$dir/tri2/.done  ]; then
  echo ---------------------------------------------------------------------
  echo "Starting (medium) triphone training in exp/tri2 on" `date`
  echo ---------------------------------------------------------------------
  steps/align_si.sh \
    --boost-silence $boost_sil --nj 24 --cmd "$train_cmd" \
    data/$dir data/lang_nosp exp_$dir/tri1 exp_$dir/tri1_ali_sub3
  steps/train_deltas.sh \
    --cmd "$train_cmd" $numLeavesTri2 $numGaussTri2 \
    data/$dir data/lang_nosp exp_$dir/tri1_ali_sub3 exp_$dir/tri2
    touch exp_$dir/tri2/.done
fi
# --cmd "$train_cmd" 2500 30000 \

if [ ! -f exp_$dir/tri3/.done  ]; then
  echo ---------------------------------------------------------------------
  echo "Starting (full) triphone training in exp/tri3 on" `date`
  echo ---------------------------------------------------------------------
  steps/align_si.sh \
    --boost-silence $boost_sil --nj $train_nj --cmd "$train_cmd" \
    data/$dir data/lang_nosp exp_$dir/tri2 exp_$dir/tri2_ali
  steps/train_deltas.sh \
    --boost-silence $boost_sil --cmd "$train_cmd" \
    $numLeavesTri3 $numGaussTri3 data/$dir data/lang_nosp exp_$dir/tri2_ali exp_$dir/tri3
    touch exp_$dir/tri3/.done
fi

# This will be used in the next segmentation
if [ ! -f exp_$dir/tri4/.done  ]; then
  echo ---------------------------------------------------------------------
  echo "Starting (lda_mllt) triphone training in exp/tri4 on" `date`
  echo ---------------------------------------------------------------------
  steps/align_si.sh \
    --boost-silence $boost_sil --nj $train_nj --cmd "$train_cmd" \
    data/$dir data/lang_nosp exp_$dir/tri3 exp_$dir/tri3_ali
  steps/train_lda_mllt.sh \
    --boost-silence $boost_sil --cmd "$train_cmd" \
    $numLeavesMLLT $numGaussMLLT data/$dir data/lang_nosp exp_$dir/tri3_ali exp_$dir/tri4
    touch exp_$dir/tri4/.done
fi

if [ ! -f exp_$dir/tri5/.done  ]; then
  echo ---------------------------------------------------------------------
  echo "Starting (SAT) triphone training in exp/tri5 on" `date`
  echo ---------------------------------------------------------------------
  steps/align_si.sh \
    --boost-silence $boost_sil --nj $train_nj --cmd "$train_cmd" \
    data/$dir data/lang_nosp exp_$dir/tri4 exp_$dir/tri4_ali
  steps/train_sat.sh \
    --boost-silence $boost_sil --cmd "$train_cmd" \
    $numLeavesSAT $numGaussSAT data/$dir data/lang_nosp exp_$dir/tri4_ali exp_$dir/tri5
    touch exp_$dir/tri5/.done
fi

if [ ! -f exp_$dir/tri5_ali/.done  ]; then
  echo ---------------------------------------------------------------------
  echo "Starting exp/tri5_ali on" `date`
  echo ---------------------------------------------------------------------
  steps/align_fmllr.sh \
    --boost-silence $boost_sil --nj $train_nj --cmd "$train_cmd" \
    data/$dir data/lang_nosp exp_$dir/tri5 exp_$dir/tri5_ali
    touch exp_$dir/tri5_ali/.done
fi

if [ ! -f exp_$dir/tri5_ali/rttm ]; then
    ./local/ali_to_rttm.sh data/$dir data/lang_nosp exp_$dir/tri5_ali
fi

