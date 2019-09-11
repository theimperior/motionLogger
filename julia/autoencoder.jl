using Flux
using CuArrays
using Printf
include("./dataManager.jl")
include("./verbose.jl")
using .verbose
using .dataManager: make_batch

dataset_folderpath = "../MATLAB/TrainingData/"
dataset_name = "2019_09_09_1658"
hidden1 = 150
hidden2 = 80
epochs = 50

train = make_batch(dataset_folderpath, "$(dataset_name)_TRAIN.mat", normalize_data=false, truncate_data=false)
val = make_batch(dataset_folderpath, "$(dataset_name)_VAL.mat", normalize_data=false, truncate_data=false)
test = make_batch(dataset_folderpath, "$(dataset_name)_TEST.mat", normalize_data=false, truncate_data=false)

train = gpu.(train)
val = gpu.(val)
test = gpu.(test)


model = Chain(
	# encoding 
	Dense(288, hidden1, relu),
	Dense(hidden1, hidden2, relu),
	Dense(hidden2, 2),
	
	# decoding
	Dense(2, hidden2, relu),
	Dense(hidden2, hidden1),
	Dense(hidden1, 288, relu),
	)
	
model = model |> gpu

loss(x) = mse(model(x), x)

opt = ADAM()

for i in 1:epochs
	Flux.train!(loss, params(model), train, opt)
	@tprintf("Epoch %i: Loss: %f", i, loss(train[1]))
end

	