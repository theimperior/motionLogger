
"""
Author: Sebastian Vendt, University of Ulm



"""

using ArgParse
s = ArgParseSettings()
@add_arg_table s begin
    "--gpu"
        help = "set, if you want to train on the GPU"
		action = :store_true
	"--eval"
		help = "set, if you want to validate instead of test after training"
		action = :store_true
    "--learn"
        help = "learning rate"
		arg_type = Float32
		default = 0.1f0
    "--epochs" 
		help = "Number of epochs"
		arg_type = Int64
		default = 100
end
parsed_args = parse_args(ARGS, s)

using Flux, Statistics
using Flux: onecold
using BSON
using Dates
using Printf
using NNlib
using FeedbackNets
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
learning_rate = parsed_args["learn"]
validate = parse_args["eval"]
const epochs = parsed_args["epochs"]
const decay_rate = 0.1f0
const decay_step = 40
const usegpu = parsed_args["gpu"]
const printout_interval = 5
const save_interval = 25
const time_format = "HH:MM:SS"
const date_format = "dd_mm_yyyy"
data_size = (48, 6) # resulting in a 240ms frame

# ARCHITECTURE
channels = 1
features1 = 32
features2 = 64
features3 = 256 # needs to find the relation between the axis which represents the screen position 
kernel1 = (3,1)  # convolute only horizontally
kernel2 = kernel1  # same here
kernel3 = (3, 6) # this should convolute all 6 rows together to map relations between the channels  
pooldims1 = (2,1)# (24,6)
pooldims2 = (2,1)# (12,6)
# pooldims3 = (2,1)# (1, 4)
inputDense1 = prod(data_size .÷ pooldims1 .÷ pooldims2 .÷ kernel3) * features3
inputDense2 = 500
inputDense3 = 500
dropout_rate = 0.1f0

dataset_folderpath = "../MATLAB/TrainingData/"

const model_save_location = "../trainedModels/"
const log_save_location = "../logs/"

if usegpu
    using CuArrays
end

debug_str = ""
@debug begin
	global debug_str
	debug_str = "DEBUG_"
	"------DEBUGGING ACTIVATED------"
end

io = nothing

function adapt_learnrate(epoch_idx)
    return init_learning_rate * decay_rate^(epoch_idx / decay_step)
end

function loss(x, y) 
	# quadratic euclidean distance + parameternorm?
	return Flux.mse(model(x), y)
end

function loss(dataset)
	loss_val = 0.0f0
	for (data, labels) in dataset
		loss_val += Tracker.data(loss(data, labels))
	end
	return loss_val / length(dataset)
end

function load_dataset()
	train = make_batch(dataset_folderpath, "", normalize_data=false, truncate_data=false)
	val = make_batch(dataset_folderpath, "", normalize_data=false, truncate_data=false)
	test = make_batch(dataset_folderpath, "", normalize_data=false, truncate_data=false)
	return (train, val, test)
end

model = Chain(
	Conv(kernel1, channels=>features1, relu, pad=map(x -> x ÷ 2, kernel1)),
	MaxPool(pooldims1, stride=pooldims1), 
	Conv(kernel2, features1=>features2, relu, pad=map(x -> x ÷ 2, kernel2)),
	MaxPool(pooldims2, stride=pooldims2),
	Conv(kernel3, features2=>features3, relu),
	# MaxPool(),
	flatten, 
	Dense(inputDense1, inputDense2, σ),
	Dropout(dropout_rate)
	Dense(inputDense2, inputDense3, σ),
	Dropout(dropout_rate)
	Dense(inputDense3, 2) # identity to output coordinates!
)

train_model(model, train_set, validation_set, test_set)
	opt = Momentum(learning_rate, momentum)
	if(validate) @printf(io, "[%s] INIT with Loss(val_set): %f\n", Dates.format(now(), time_format), loss(validation_set)) 
	else @printf(io, "[%s] INIT with Loss(test_set): %f\n", Dates.format(now(), time_format), loss(test_set)) end
	
	 
    for i in 1:epochs
		flush(io)
        Flux.train!(loss, params(model), train_set, opt)
        opt.eta = adapt_learnrate(i)
        if ( rem(i, printout_interval) == 0 ) 
			@printf(io, "[%s] Epoch %3d: Loss: %f\n", Dates.format(now(), time_format), i, loss(train_set)) 
		end 
    end
	
	if(validate) @printf(io, "[%s] FINAL Loss(val_set): %f\n", Dates.format(now(), time_format), loss(validation_set)) 
	else @printf(io, "[%s] FINAL Loss(test_set): %f\n", Dates.format(now(), time_format), loss(test_set)) 
end

# logging framework 
fp = "$(log_save_location)$(debug_str)log_$(Dates.format(now(), date_format)).log"
io = open(fp, "a+")
global_logger(SimpleLogger(io)) # for debug outputs
@printf(Base.stdout, "Logging to File: %s\n", fp)
@printf(io, "\n--------[%s %s]--------\n", Dates.format(now(), date_format), Dates.format(now(), time_format))
# dump configuration 
@debug begin
	for symbol in names(Main)
		var = "$(symbol) = $(eval(symbol))"
		@printf(io, "%s\n", var)
	end
	"--------End of VAR DUMP--------"
end
flush(io)
flush(Base.stdout)

train_set, validation_set, test_set = load_dataset()

train_model(model, train_set, validation_set, test_set)




