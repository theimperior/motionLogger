"""
Author: Sebastian Vendt, University of Ulm



"""

using Flux, Statistics
using Flux: onecold
using BSON
using Dates
using Printf
using NNlib
include("./dataManager.jl")
using .dataManager: make_batch
using Logging
import LinearAlgebra: norm
norm(x::TrackedArray{T}) where T = sqrt(sum(abs2.(x)) + eps(T)) 


######################
# PARAMETERS
######################
const batch_size = 100
const momentum = 0.9f0
const lambda = 0.0005f0
init_learning_rate = 0.1f0
learning_rate = init_learning_rate
const epochs = 100
const decay_rate = 0.1f0
const decay_step = 40
const usegpu = true
const printout_interval = 5
const save_interval = 25
const time_format = "HH:MM:SS"
data_size = (50, 1) # MNIST is using 28, 28

# ARCHITECTURE
inputDense1
inputDense2
inputDense3
classes = 2
# enter the datasets and models you want to train

dataset_folderpath = "../MATLAB/TrainingData/"

const model_save_location = "../trainedModels/"
const log_save_location = "../logs/"


function adapt_learnrate(epoch_idx)
    return init_learning_rate * decay_rate^(epoch_idx / decay_step)
end


if usegpu
    using CuArrays
end


model = Chain(
	Conv(kernel, channels=>features, relu, pad=map(x -> x ÷ 2, kernel)),
	MaxPool(pooldims1, stride=()),
	Conv(relu, pad=map(x -> x ÷ 2, kernel)),
	MaxPool(),
	Conv(relu, pad=map(x -> x ÷ 2, kernel)),
	MaxPool(),
	flatten, 
	Dense(inputDense1, inputDense2, σ),
	Dense(inputDense2, inputDense3, σ),
	Dense(inputDense3, classes) # identity to output coordinates!
)


