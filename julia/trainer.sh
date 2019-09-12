#!/bin/bash
CUDA_VISIBLE_DEVICES='1'

julia $1 # net.jl
