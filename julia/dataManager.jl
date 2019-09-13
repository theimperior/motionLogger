module dataManager

using MAT 
using Base.Iterators: repeated, partition
using Statistics
using Flux.Data.MNIST
using Flux:onehotbatch

# dimension of coordinates (labels): (x, y)
lbls_dims = (1080, 980)
lbls_offset = (0, 699)

"""
	make_minibatch(X, Y, idxset)
	
loads and bundles training data and labels into batches 
X should be of size Width x Height x channels x batchsize
Y should be of size 2 x batchsize
"""
function make_minibatch(X, Y, idxset)
    X_batch = Array{Float32}(undef, size(X, 1), size(X, 2), 1, length(idxset))
    Y_batch = Array{Float32}(undef, 2, length(idxset))
    for i in 1:length(idxset)
        
        X_batch[:, :, :, i] = Float32.(X[:, :, :, idxset[i]])
        Y_batch[:, i] = Float32.(Y[:, idxset[i]])
    end    
    return (X_batch, Y_batch)
end

"""
    make_batch(filepath, filenames...; batch_size=100, normalize_data=true, truncate_data=false)
    
Creates batches with size batch_size(default 100) from filenames at given filepath. Images will be normalized if normalize is set (default true). 
If batch_size equals -1 the batch size will be the size of the dataset
Structure of the .mat file: 

    fieldname | size
    ----------------
       data   | 50 x 6 x N
  bin_targets | 2 x N (1: x, 2: y)

where N denotes the number of samples, 50 is the window size and 6 are the number of channels
"""
function make_batch(filepath, filenames...; batch_size=100, normalize_data=true, truncate_data=false)
    data = nothing # Array{Float64}(undef, 0)
    labels = nothing # Array{Float64}(undef, 0)
    for (i, filename) in enumerate(filenames)
        # load the data from the mat file
        file = "$filepath$filename"
        @debug("Reading $(i) of $(length(filenames)) from $(file)")
        matfile = matopen(file)
        # size(images) = (N, width, height, 1)
        dataPart = read(matfile, "data")
        # size(bin_targets) = (N, 10)
        labelsPart = read(matfile, "labels")
        close(matfile) 
        if (isnothing(data)) data = dataPart; labels = labelsPart;
        else
        data = cat(dims=3, data, dataPart)
        labels = cat(dims=2, labels, labelsPart)   
        end
    end
	
	# add singleton dimension and permute dims so it matches the convention of Flux width x height x channels x batchsize(Setsize)   
	data = cat(dims=4, data)
	
	# normalize the labels 
	labels = (labels .- lbls_offset) ./ lbls_dims

    # rearrange the data array 
	# size(data) = (50, 6, 1, N)
    data = permutedims(data, (1, 2, 4, 3))

    @debug("Dimension of data $(size(data))")
    @debug("Dimension of binary targets $(size(labels))")
    
    
    if(normalize_data)
		normalize!(data, truncate_data)
	end
    
    # Convert to Float32
    labels = convert(Array{Float32}, labels)
    data = convert(Array{Float32}, data) 
	
    # display one sample of the images depends on PyPlot!
    # matshow(dropdims(images[:,:,:,10], dims=3), cmap=PyPlot.cm.gray, vmin=0, vmax=255)
	
	 if ( batch_size == -1 ) 
	    batch_size = size(data, 4)
	 end
    idxsets = partition(1:size(data, 4), batch_size)
    data_set = [make_minibatch(data, labels, i) for i in idxsets];
    
    return data_set
end # function make_batch

"""
normalize input images along the batch and channel dimension
input should have standart flux order: Widht x height x channels x batchsize
if truncate is set to true the last 1% beyond 2.576 sigma will be clipped to 2.576 sigma
"""
function normalize!(data, truncate)
	mean_data = mean(data, dims=4)
    std_data = std(data, mean=mean_data, dims=4)
	
	setsize = size(data, 4)
    
	@debug("normalize dataset")
	std_data_tmp = copy(std_data)
	std_data_tmp[std_data_tmp .== 0] .= 1
	for i in 1:setsize
		data[:, :, :, i] = (data[:, :, :, i] - mean_data) ./ std_data_tmp
	end
	if(truncate)
		# truncate the last 1% beyond 2.576 sigma 
		data[data .> 2.576] .= 2.576
		data[data .< -2.576] .= -2.576
	end
	return (mean_data, std_data)
end

end # module dataManager
