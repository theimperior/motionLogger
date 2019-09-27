#!/bin/bash
CUDA_VISIBLE_DEVICES='1'

julia net_2stage.jl --gpu --eval --csv --logmsg "second stage Hyperparameter Tuning with 1 net"

