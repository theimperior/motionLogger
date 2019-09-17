#!/bin/bash
CUDA_VISIBLE_DEVICES='1'

julia net.jl --gpu --epochs 10 --csv --logmsg "performance test with model as global variable" --eval
# julia net_local.jl --gpu --epochs 10 --csv --logmsg "performance test with model as local variable" --eval

