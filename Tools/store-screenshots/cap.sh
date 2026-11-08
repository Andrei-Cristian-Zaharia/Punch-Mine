#!/bin/zsh
# usage: cap.sh <udid> <outdir> <name> <save> <screen|-> <wait seconds> [extra shots spaced 0.7s]
S=${0:A:h}; UDID=$1; OUT=$2; NAME=$3; SAVE=$4; SCREEN=$5; WAIT=$6; EXTRA=${7:-0}

[[ $SAVE != away ]] && python3 $S/make_saves.py >/dev/null
xcrun simctl terminate $UDID com.andreizaharia.punchmine >/dev/null 2>&1
ARGS=(-debugSave $S/save-$SAVE.json)
[[ $SCREEN != "-" ]] && ARGS+=(-debugScreen $SCREEN)
xcrun simctl launch $UDID com.andreizaharia.punchmine $ARGS >/dev/null
sleep $WAIT
xcrun simctl io $UDID screenshot --type=png $OUT/$NAME.png >/dev/null 2>&1
for i in $(seq 1 $EXTRA); do sleep 0.7; xcrun simctl io $UDID screenshot --type=png $OUT/$NAME-$i.png >/dev/null 2>&1; done
