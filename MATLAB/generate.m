% One need to determine the framesize and frameoffset beforehand...
framesize = 48;
frameoffset = 25;
maxFrameShift = 10;
splitRatio = [70, 20, 10]; % percentage of training, validation, testing needs to add up to 100!!!
file = '2019_08_16_1856';
% read the csv and start in the second row, first column
csvData = csvread(strcat('AppData/', file, '.csv'), 2, 0);

% split into seperate sets and save them as mat (normalization will be done
% in julia)
[train_data, train_lbls] = generateTrainingDataFromCSV(csvData, 0, splitRatio(1), framesize, frameoffset, maxFrameShift);
[validation_data, validation_lbls] = generateTrainingDataFromCSV(csvData, splitRatio(1), splitRatio(2), framesize, frameoffset, maxFrameShift);
[test_data, test_lbls] = generateTrainingDataFromCSV(csvData, splitRatio(2) + splitRatio(1), splitRatio(3), framesize, frameoffset, maxFrameShift);

% shuffle the datasets
shuffleSet(train_data, train_lbls);
shuffleSet(validation_data, validation_lbls);
shuffleSet(test_data, test_lbls);

data = train_data;
labels = train_lbls;
save(strcat('TrainingData/', file, '_TRAIN.mat'),'data', 'labels')

data = validation_data;
labels = validation_lbls;
save(strcat('TrainingData/', file, '_VAL.mat'),'data', 'labels')

data = test_data;
labels = test_lbls;
save(strcat('TrainingData/', file, '_TEST.mat'),'data', 'labels')

dataset = cat(3, train_data, validation_data, test_data);
% gathering some statistics
% 1. pointerDownTime equals the time a finger is residing on the screen 
% 2. timeBetweenTouchEvents indicating the frequency of the taps
% 3. max/min Values of Frames indicating the strength of the taps 
POINTERDOWNTIME1 = 14;
POINTERDOWNTIME2 = 15;
TIMEBETWEENTOUCHEVENTS = 16;

indicesPDT1 = find(csvData(:, POINTERDOWNTIME1) ~= 0);
indicesPDT2 = find(csvData(:, POINTERDOWNTIME2) ~= 0);
indicesTBT = find(csvData(:, TIMEBETWEENTOUCHEVENTS) ~= 0);
pointerDownTimes = csvData(indicesPDT1, POINTERDOWNTIME1);
pointerDownTimes = cat(1, pointerDownTimes, csvData(indicesPDT1, POINTERDOWNTIME1));
TimeBetweenTouchEvents = csvData(indicesTBT(2:end), TIMEBETWEENTOUCHEVENTS);

maxGYRO = [max(dataset(:,:,1)')', max(dataset(:,:,2)')', max(dataset(:,:,3)')'];
maxACC = [max(dataset(:,:,4)')', max(dataset(:,:,5)')', max(dataset(:,:,6)')'];

fig1 = figure;
histogram(pointerDownTimes ./ 1000000) % Divide from ns to ms 
title('Histogram of the Duriation of touch events in ms')
fig2 = figure;
histogram(TimeBetweenTouchEvents ./ 1000000) % Divide from ns to ms
title('Histogram of the time between sequential touch events in ms')
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

function [dataset, labels] = shuffleSet(data, lbls)
    shuffle = randperm(size(data, 3));
    dataset = data(:, :, shuffle);
    labels = lbls(:, shuffle);
end
