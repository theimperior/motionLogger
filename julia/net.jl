
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
	"--logmsg"
		help = "additional message describing the training log"
		arg_type = String
		default = ""
	"--csv"
		help = "set, if you additionally want a csv output of the learning process"
		action = :store_true
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
include("./verbose.jl")
using .dataManager: make_batch
using .verbose
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
validate = parsed_args["eval"]
const epochs = parsed_args["epochs"]
const decay_rate = 0.1f0
const decay_step = 40
const usegpu = parsed_args["gpu"]
const printout_interval = 5
const save_interval = 25
const time_format = "HH:MM:SS"
const date_format = "dd_mm_yyyy"
data_size = (60, 6) # resulting in a 300ms frame

# ARCHITECTURE
channels = 1
features1 = 32
features2 = 64
features3 = 128 # needs to find the relation between the axis which represents the screen position 
kernel1 = (3,1)  # convolute only horizontally
kernel2 = kernel1  # same here
kernel3 = (3, 6) # this should convolute all 6 rows together to map relations between the channels  
pooldims1 = (2,1)# (30,6)
pooldims2 = (2,1)# (15,6)
# pooldims3 = (2,1)# (1, 4)
inputDense1 = 1664 # prod(data_size .÷ pooldims1 .÷ pooldims2 .÷ kernel3) * features3
inputDense2 = 600
inputDense3 = 300
dropout_rate = 0.3f0

dataset_folderpath = "../MATLAB/TrainingData/"
dataset_name = "2019_09_09_1658"

const model_save_location = "../trainedModels/"
const log_save_location = "./logs/"

if usegpu
    using CuArrays
end

debug_str = ""
log_msg = parsed_args["logmsg"]
csv_out = parse_args["csv"]
@debug begin
	global debug_str
	debug_str = "DEBUG_"
	"------DEBUGGING ACTIVATED------"
end

io = nothing
io_csv = nothing

function adapt_learnrate(epoch_idx)
    return init_learning_rate * decay_rate^(epoch_idx / decay_step)
end

function loss(x, y) 
	# quadratic euclidean distance + parameternorm
	return Flux.mse(model(x), y) + lambda * sum(norm, params(model))
end

function loss(dataset)
	loss_val = 0.0f0
	for (data, labels) in dataset
		loss_val += Tracker.data(loss(data, labels))
	end
	return loss_val / length(dataset)
end

function load_dataset()
	train = make_batch(dataset_folderpath, "$(dataset_name)_TRAIN.mat", normalize_data=false, truncate_data=false)
	val = make_batch(dataset_folderpath, "$(dataset_name)_VAL.mat", normalize_data=false, truncate_data=false)
	test = make_batch(dataset_folderpath, "$(dataset_name)_TEST.mat", normalize_data=false, truncate_data=false)
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
	Dense(inputDense1, inputDense2, relu),
	Dropout(dropout_rate),
	Dense(inputDense2, inputDense3, relu),
	Dropout(dropout_rate),
	Dense(inputDense3, 2, σ), # coordinates between 0 and 1
)

function log(epoch, use_testset)
	Flux.testmode!(model, true)
	
	if(epoch == 0 | epoch == epochs) # evalutation phase 
		if(use_testset) @printf(io, "[%s] Epoch %3d: Loss(test): %f\n", Dates.format(now(), time_format), epoch, loss(test_set)) 
		else @printf(io, "[%s] Epoch %3d: Loss(val): %f\n", Dates.format(now(), time_format), epoch, loss(validation_set)) end
	else # learning phase
		 @printf(io, "[%s] Epoch %3d: Loss(train): %f\n", Dates.format(now(), time_format), epoch, loss(train_set)) 
	end
	
	if(csv_out) @printf(io_csv, "%d, %f\n", epoch, loss(train_set)) end
	
	Flux.testmode!(model, false)
end

function train_model()
	opt = Momentum(learning_rate, momentum)
	log(0, !validate)
    for i in 1:epochs
		flush(io)
        Flux.testmode!(model, false) # bring model in training mode
        Flux.train!(loss, params(model), train_set, opt)
        opt.eta = adapt_learnrate(i)
        if (rem(i, printout_interval) == 0) 
			log(i, false)
		end 
    end
	log(epochs, !validate)
end

# logging framework 
fp = "$(log_save_location)$(debug_str)log_$(Dates.format(now(), date_format)).log"
io = open(fp, "a+")
global_logger(SimpleLogger(io)) # for debug outputs
@printf(Base.stdout, "Logging to File: %s\n", fp)
@printf(io, "\n--------[%s %s]--------\n", Dates.format(now(), date_format), Dates.format(now(), time_format))
@printf(io, "%s\n", log_msg)

# csv handling
if (csv_out)
	fp_csv = "$(log_save_location)$(debug_str)csv_$(Dates.format(now(), date_format)).csv"
	io_csv = open(fp_csv, "w+") # read, write, create, truncate
	@printf(io_csv, "epoch, loss(train)\n")
end	

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

if (usegpu)
	train_set = gpu.(train_set)
	validation_set = gpu.(validation_set)
	test_set = gpu.(test_set)
	model = gpu(model)
end


train_model()





