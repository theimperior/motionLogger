#!/bin/bash
CUDA_VISIBLE_DEVICES='1'

julia net.jl --gpu --eval --logmsg "Random Grid Search"

