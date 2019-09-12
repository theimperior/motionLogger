using Flux
using CuArrays
using Printf
include("./dataManager.jl")
include("./verbose.jl")
using .verbose
using .dataManager: make_batch

using FeedbackNets

dataset_folderpath = "../MATLAB/TrainingData/"
dataset_name = "2019_09_09_1658"
hidden1 = 150
hidden2 = 80
epochs = 100


train = make_batch(dataset_folderpath, "$(dataset_name)_TRAIN.mat", normalize_data=false, truncate_data=false)
val = make_batch(dataset_folderpath, "$(dataset_name)_VAL.mat", normalize_data=false, truncate_data=false)
test = make_batch(dataset_folderpath, "$(dataset_name)_TEST.mat", normalize_data=false, truncate_data=false)

train = gpu.(train)
val = gpu.(val)
test = gpu.(test)


model = Chain(
	# encoding
	flatten, 
	Dense(288, hidden1, relu),
	Dense(hidden1, hidden2, relu),
	Dense(hidden2, 2),
	
	# decoding
	Dense(2, hidden2, relu),
	Dense(hidden2, hidden1),
	Dense(hidden1, 288, relu),
	)
	
model = model |> gpu

loss(x, y) = Flux.mse(model(x), flatten(x))


function loss(dataset)
   loss_val = 0.0f0
   for (data, labels) in dataset
      loss_val += loss(data, labels)
   end
   return loss_val / length(dataset)
end

const moment = 0.9f0
const decay_rate = 0.1f0
const decay_step = 40
const init_learning_rate = 0.3f0

function adapt_learnrate(epoch_idx)
    return init_learning_rate * decay_rate^(epoch_idx / decay_step)
end

opt = Momentum(init_learning_rate, moment)

@tprintf("INIT: Loss: %f\n", loss(train))
for i in 1:epochs
	Flux.train!(loss, params(model), train, opt)
	@tprintf("Epoch %i: Loss: %f\n", i, loss(train))
	opt.eta = adapt_learnrate(i)
end

	
