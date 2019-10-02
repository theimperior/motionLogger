function [data, labels] = generateTrainingDataFromCSV(file, offset, len, framesize, frameoffset, maxFrameShift)
% generateTrainingDataFromCSV(file, offset, length, framesize, frameoffset, maxFrameShift)
% generating frames with fixed number of samples, parametrized by framesize
% and frameoffset. frameoffset determines the number of sample to include
% before the actual touch event
% maxFrameShift determines the jitter in both directions when determining
% the origin of the frame based on the postion of the touch event
% finally offset and lenght defined in percent (in 100 percent) of the dataset to be used
% offset + lenght cannot be larger than 100
%
% Returns two matrices
% data: 
% framesize x 6 x N (Where N denotes the total number of samples)
%
% labels:
% 2 x N 

  X_COORD = 10;
  Y_COORD = 11;

  
  % find the action down events
  indices = find(file(:,9) == 1);
  events = length(indices);
 
  
  offset_index = floor(length(indices) * offset / 100) + 1;
  len_index = floor(length(indices) * len / 100) + offset_index - 1;
  
  indices = indices(offset_index:len_index);
  fprintf("%d touch events in %d sensor samples, using %d:%d\n", events, size(file, 1),offset_index, len_index);
  
  data = []; % zeros(framesize, 6, size(indices,1) * (2 * maxFrameShift + 1));
  labels = []; % zeros(2, size(indices,1) * (2 * maxFrameShift + 1));
  % create the frames and labels
  for i = -maxFrameShift:maxFrameShift
      data = cat(3, data, getSamplesFromData(file, indices + i, framesize, frameoffset));
      labels = cat(2, labels, file(indices, X_COORD:Y_COORD)');
  end
  fprintf("created %d frames out of %d touch events\n", size(data, 3), length(indices));
  labels = bsxfun(@minus, labels, [0; 699])
end

function samples = getSamplesFromData(file, indices, framesize, frameoffset)
  GYRO_X = 2;
  GYRO_Y = 3;
  GYRO_Z = 4;
  ACC_X = 6;
  ACC_Y = 7;  
  ACC_Z = 8;
  
  samples = zeros(framesize, 6, size(indices,1));
  dataidx = 1;
  for i = indices'
      % creates a (framesize x 6 x batchsize) tensor 
      if (i-frameoffset+framesize < size(file, 1) && i - frameoffset > 0) 
          samples(:, :, dataidx) = cat(2, file(i-frameoffset:i-frameoffset+framesize-1,GYRO_X:GYRO_Z), file(i-frameoffset:i-frameoffset+framesize-1,ACC_X:ACC_Z));
          dataidx = dataidx + 1;
      end
  end
end




