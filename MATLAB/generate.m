% One need to determine the framesize and frameoffset beforehand...
framesize = 50;
frameoffset = 25;
maxFrameShift = 10;
splitRatio = [70, 20, 10]; % percentage of training, validation, testing needs to add up to 100!!!
file = '2019_08_08_1256';
filepointer = csvread(strcat('AppData/', file, '.csv'), 2, 0);
% get the training data and the labels
[dataset, lbls] = generateTrainingDataFromCSV(filepointer, framesize, frameoffset, maxFrameShift);

% gathering some statistics
% 1. pointerDownTime equals the time a finger is residing on the screen 
% 2. timeBetweenTouchEvents indicating the frequency of the taps
% 3. max/min Values of Frames indicating the strength of the taps 
POINTERDOWNTIME1 = 14;
POINTERDOWNTIME2 = 15;
TIMEBETWEENTOUCHEVENTS = 16;

indicesPDT1 = find(filepointer(:, POINTERDOWNTIME1) ~= 0);
indicesPDT2 = find(filepointer(:, POINTERDOWNTIME2) ~= 0);
indicesTBT = find(filepointer(:, TIMEBETWEENTOUCHEVENTS) ~= 0);
pointerDownTimes = filepointer(indicesPDT1, POINTERDOWNTIME1);
pointerDownTimes = cat(1, pointerDownTimes, filepointer(indicesPDT1, POINTERDOWNTIME1));
TimeBetweenTouchEvents = filepointer(indicesTBT(2:end), TIMEBETWEENTOUCHEVENTS);

maxGYRO = [max(dataset(:,:,1)')', max(dataset(:,:,2)')', max(dataset(:,:,3)')'];
maxACC = [max(dataset(:,:,4)')', max(dataset(:,:,5)')', max(dataset(:,:,6)')'];

fig1 = figure;
% TODO Something is still wrong with these times...
histogram(pointerDownTimes ./ 1000000) % Divide from ns to ms 
title('Histogram of the Duriation of touch events')
fig2 = figure;
histogram(TimeBetweenTouchEvents ./ 1000000) % Divide from ns to ms
title('Histogram of the time between sequential touch events')
fig3 = figure;
subplot(2,3,1)
nbins = 10;
histogram(maxGYRO(:, 1), nbins)
title('Hist Max Gyro X')
subplot(2,3,2)
histogram(maxGYRO(:, 2), nbins)
title('Hist Max Gyro Y')
subplot(2,3,3)
histogram(maxGYRO(:, 3), nbins)
title('Hist Max Gyro Z')
subplot(2,3,4)
histogram(maxACC(:, 1), nbins)
title('Hist Max ACC X')
subplot(2,3,5)
histogram(maxACC(:, 2), nbins)
title('Hist Max ACC Y')
subplot(2,3,6)
histogram(maxACC(:, 3), nbins)
title('Hist Max ACC Z')

% shuffle the dataset
shuffle = randperm(size(dataset, 3));
dataset = dataset(:, :, shuffle);
lbls = lbls(:, shuffle);

% split into seperate sets and save them as mat (normalization will be done
% in julia)
splitTrain = floor(size(dataset, 3) * splitRatio(1) / 100 )
data = dataset(:, :, 1:splitTrain);
labels = lbls(:, 1:splitTrain);
save(strcat('TrainingData/', file, '_TRAIN_.mat'),'data', 'labels')

splitVal = floor(size(dataset, 3) * (splitRatio(2) + splitRatio(1)) / 100 )
data = dataset(:, :, splitTrain+1:splitVal);
labels = lbls(:, splitTrain+1:splitVal);
save(strcat('TrainingData/', file, '_VAL_.mat'),'data', 'labels')

data = dataset(:, :, splitVal+1:end);
labels = lbls(:, splitVal+1:end);
save(strcat('TrainingData/', file, '_TEST_.mat'),'data', 'labels')
