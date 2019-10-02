#!/bin/bash
CUDA_VISIBLE_DEVICES='1'

julia net_2stage.jl --gpu --csv --logmsg "second stage Hyperparameter Tuning with 1 net, reevaluation with fixed epochs now, using testset"

