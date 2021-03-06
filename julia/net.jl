
"""
Author: Sebastian Vendt, University of Ulm
This script implements the convolutional neural network for infering tap locations from motion data frames. 
For detailed documentation please read through ReportMotionLogger.pdf in the github repo.
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
	"--runD"
		help = "set, if you want to run the default config"
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
using Random
import LinearAlgebra: norm
norm(x::TrackedArray{T}) where T = sqrt(sum(abs2.(x)) + eps(T)) 

######################
# PARAMETERS
######################
const batch_size = 100
momentum = 0.99f0
const lambda = 0.0005f0
const delta = 0.00006
learning_rate = 0.03f0
validate = parsed_args["eval"]
const epochs = parsed_args["epochs"]
const decay_rate = 0.1f0
const decay_step = 60
const usegpu = parsed_args["gpu"]
const printout_interval = 2
const time_format = "HH:MM:SS"
const date_format = "dd_mm_yyyy"
data_size = (60, 6) # resulting in a 300ms frame

# DEFAULT ARCHITECTURE
channels = 1
features = [32, 64, 128] # needs to find the relation between the axis which represents the screen position 
kernel = [(5,1), (5,1), (2,6)]  # convolute only horizontally, last should convolute all 6 rows together to map relations between the channels  
pooldims = [(3,1), (3,1)]# (30,6) -> (15,6)
# formula for calculating output dimensions of convolution: 
# dim1 = ((dim1 - Filtersize + 2 * padding) / stride) + 1
inputDense = [0, 600, 300] # the first dense layer is automatically calculated
dropout_rate = 0.3f0

# random search values
rs_momentum = [0.9, 0.92, 0.94, 0.96, 0.98, 0.99]
rs_features = [[32, 64, 128], [64, 64, 64], [32, 32, 32], [96, 192, 192]]
rs_dropout_rate = [0.1, 0.3, 0.4, 0.6, 0.8]
rs_kernel = [[(3,1), (3,1), (3,6)], [(5,1), (5,1), (3,6)], [(7,1), (7,1), (3,6)], [(3,1), (3,1), (2,6)], [(5,1), (5,1), (2,6)], [(7,1), (7,1), (2,6)], 
				[(7,1), (5,1), (2,6)], [(7,1), (5,1), (3,6)], [(5,1), (3,1), (2,6)], [(5,1), (3,1), (3,6)]]
rs_pooldims = [[(2,1), (2,1)], [(3,1), (3,1)]]
rs_learning_rate = [1, 0.3, 0.1, 0.03, 0.01, 0.003, 0.001]

dataset_folderpath = "../MATLAB/TrainingData/"
dataset_name = "2019_09_09_1658"

const model_save_location = "../trainedModels/"
const log_save_location = "./logs/"

if usegpu
    using CuArrays
end

debug_str = ""
log_msg = parsed_args["logmsg"]
csv_out = parsed_args["csv"]
runD = parsed_args["runD"]
io = nothing
io_csv = nothing
@debug begin
	global debug_str
	debug_str = "DEBUG_"
	"------DEBUGGING ACTIVATED------"
end

function adapt_learnrate(epoch_idx)
    return learning_rate * decay_rate^(epoch_idx / decay_step)
end

# TODO different idea for the accuracy: draw circle around ground truth and if prediction lays within the circle count this as a hit 
function accuracy(model, x, y)
	y_hat = Tracker.data(model(x))
	return mean(mapslices(button_number, y_hat, dims=1) .== mapslices(button_number, y, dims=1))
end

function accuracy(model, dataset)
   acc = 0.0f0
   for (data, labels) in dataset
      acc += accuracy(model, data, labels)
   end
   return acc / length(dataset)
end

function button_number(X)
	return (X[1] * 1080) ÷ 360 + 3 * ((X[2] * 980) ÷ 245)
end

function loss(model, x, y) 
	# quadratic euclidean distance + norm 
	return Flux.mse(model(x), y) + lambda * sum(norm, params(model))
end

function loss(model, dataset)
	loss_val = 0.0f0
	for (data, labels) in dataset
		loss_val += Tracker.data(loss(model, data, labels))
	end
	return loss_val / length(dataset)
end

function load_dataset()
	train = make_batch(dataset_folderpath, "$(dataset_name)_TRAIN.mat", normalize_data=false, truncate_data=false)
	val = make_batch(dataset_folderpath, "$(dataset_name)_VAL.mat", normalize_data=false, truncate_data=false)
	test = make_batch(dataset_folderpath, "$(dataset_name)_TEST.mat", normalize_data=false, truncate_data=false)
	return (train, val, test)
end

function create_model()
	return Chain(
		Conv(kernel[1], channels=>features[1], relu, pad=map(x -> x ÷ 2, kernel[1])),
		MaxPool(pooldims[1], stride=pooldims[1]), 
		Conv(kernel[2], features[1]=>features[2], relu, pad=map(x -> x ÷ 2, kernel[2])),
		MaxPool(pooldims[2], stride=pooldims[2]),
		Conv(kernel[3], features[2]=>features[3], relu),
		# MaxPool(),
		flatten, 
		Dense(prod((data_size .÷ pooldims[1] .÷ pooldims[2]) .- kernel[3] .+ 1) * features[3], inputDense[2], relu),
		Dropout(dropout_rate),
		Dense(inputDense[2], inputDense[3], relu),
		Dropout(dropout_rate),
		Dense(inputDense[3], 2, σ), # coordinates between 0 and 1
	)
end

function log(model, epoch, use_testset)
	Flux.testmode!(model, true)
	
	if(epoch == 0) # evalutation phase 
		if(use_testset) @printf(io, "[%s] INIT Loss(test): f% Accuarcy: %f\n", Dates.format(now(), time_format), loss(model, test_set), accuracy(model, test_set)) 
		else @printf(io, "[%s] INIT Loss(val): %f Accuarcy: %f\n", Dates.format(now(), time_format), loss(model, validation_set), accuracy(model, validation_set)) end
	elseif(epoch == epochs)
        @printf(io, "[%s] Epoch %3d: Loss(train): %f Loss(val): %f\n", Dates.format(now(), time_format), epoch, loss(model, train_set), loss(model, validation_set))
		if(use_testset) 
		   @printf(io, "[%s] FINAL(%d) Loss(test): %f Accuarcy: %f\n", Dates.format(now(), time_format), epoch, loss(model, test_set), accuracy(model, test_set)) 
		else 
		   @printf(io, "[%s] FINAL(%d) Loss(val): %f Accuarcy: %f\n", Dates.format(now(), time_format), epoch, loss(model, validation_set), accuracy(model, validation_set)) 
	   end
	else # learning phase
		if (rem(epoch, printout_interval) == 0) 
			@printf(io, "[%s] Epoch %3d: Loss(train): %f Loss(val): %f\n", Dates.format(now(), time_format), epoch, loss(model, train_set), loss(model, validation_set)) 
		end
	end

	Flux.testmode!(model, false)
end

function log_csv(model, epoch)
	Flux.testmode!(model, true)
	if(csv_out) @printf(io_csv, "%d, %f, %f\n", epoch, loss(model, train_set), loss(model, validation_set)) end
	Flux.testmode!(model, false)
end

function eval_model(model)
	Flux.testmode!(model, true)
	if (validate) return (loss(model, validation_set), accuracy(model, validation_set))
	else return (loss(model, test_set), accuracy(model, test_set)) end
end

function train_model()
	model = create_model()
	if (usegpu) model = gpu(model) end
	opt = Momentum(learning_rate, momentum)
	log(model, 0, !validate)
	Flux.testmode!(model, false) # bring model in training mode
	last_loss = loss(model, train_set)
    for i in 1:epochs
		flush(io)
        Flux.train!((x, y) -> loss(model, x, y), params(model), train_set, opt)
        opt.eta = adapt_learnrate(i)
		log_csv(model, i)
		log(model, i, !validate)
    end
    return eval_model(model)
end

function random_search()
	rng = MersenneTwister()
	results = []
	global epochs = 40
	for search in 1:800
		# create random set
		global momentum = rand(rng, rs_momentum)
		global features = rand(rng, rs_features)
		global dropout_rate = rand(rng, rs_dropout_rate)
		global kernel = rand(rng, rs_kernel)
		global pooldims = rand(rng, rs_pooldims)
		global learning_rate = rand(rng, rs_learning_rate)
		
		# printf configuration
		config1 = "momentum$(momentum), features=$(features), dropout_rate=$(dropout_rate)"
		config2 = "kernel=$(kernel), pooldims=$(pooldims), learning_rate=$(learning_rate)"
		@printf(io, "\nSearch %d of %d\n", search, 500)
		@printf(io, "%s\n", config1)
		@printf(io, "%s\n\n", config2)
		
		(loss, accuracy) = train_model()
		push!(results, (search, loss, accuracy))
	end
	return results
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
	@printf(io_csv, "epoch, loss(train), loss(val)\n")
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

train, validation, test = load_dataset()

if (usegpu)
	const train_set = gpu.(train)
	const validation_set = gpu.(validation)
	const test_set = gpu.(test)
end

if(!runD)
	results = random_search()
	BSON.@save "results.bson" results
	#TODO sort and print best 5-10 results 
	sort!(results, by = x -> x[2])
	# print results 
	@printf("Best results by Loss:\n")
	for idx in 1:5 
		@printf("#%d: Loss %f, accuracy %f in Search: %d\n", idx, results[idx][2], results[idx][3], results[idx][1])
	end
	
	sort!(results, by = x -> x[3], rev=true)
	@printf("Best results by Accuarcy:\n")
	for idx in 1:5 
		@printf("#%d: Accuarcy: %f, Loss %f in Search: %d\n", idx, results[idx][3], results[idx][2], results[idx][1])
	end
else 
	train_model() 
end
