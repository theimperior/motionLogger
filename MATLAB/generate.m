% One need to determine the framesize and frameoffset beforehand...
framesize = 48;
frameoffset = 25;
maxFrameShift = 10;
splitRatio = [70, 20, 10]; % percentage of training, validation, testing needs to add up to 100!!!
file = '2019_09_09_1658';
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

% remove the 8 largest times. These are the break times 
TimeBetweenTouchEvents = sort(TimeBetweenTouchEvents);
TimeBetweenTouchEvents = TimeBetweenTouchEvents(1:end-8);

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

function dataout = removeoutliers(datain)
%REMOVEOUTLIERS   Remove outliers from data using the Thompson Tau method.
%   For vectors, REMOVEOUTLIERS(datain) removes the elements in datain that
%   are considered outliers as defined by the Thompson Tau method. This
%   applies to any data vector greater than three elements in length, with
%   no upper limit (other than that of the machine running the script).
%   Additionally, the output vector is sorted in ascending order.
%
%   Example: If datain = [1 34 35 35 33 34 37 38 35 35 36 150]
%
%   then removeoutliers(datain) will return the vector:
%       dataout = 33 34 34 35 35 35 35 36 37 38
%
%   See also MEDIAN, STD, MIN, MAX, VAR, COV, MODE.
%   This function was written by Vince Petaccio on July 30, 2009.
n=length(datain); %Determine the number of samples in datain
if n < 3
    display(['ERROR: There must be at least 3 samples in the' ...
        ' data set in order to use the removeoutliers function.']);
else
    S=std(datain); %Calculate S, the sample standard deviation
    xbar=mean(datain); %Calculate the sample mean
    %tau is a vector containing values for Thompson's Tau
    tau = [1.150 1.393 1.572 1.656 1.711 1.749 1.777 1.798 1.815 1.829 ...
        1.840 1.849 1.858 1.865 1.871 1.876 1.881 1.885 1.889 1.893 ...
        1.896 1.899 1.902 1.904 1.906 1.908 1.910 1.911 1.913 1.914 ...
        1.916 1.917 1.919 1.920 1.921 1.922 1.923 1.924];
    %Determine the value of S times Tau
    if n > length(tau)
        TS=1.960*S; %For n > 40
    else
        TS=tau(n)*S; %For samples of size 3 < n < 40
    end
    %Sort the input data vector so that removing the extreme values
    %becomes an arbitrary task
    dataout = sort(datain);
    %Compare the values of extreme high data points to TS
    while abs((max(dataout)-xbar)) > TS 
        dataout=dataout(1:(length(dataout)-1));
        %Determine the NEW value of S times Tau
        S=std(dataout);
        xbar=mean(dataout);
        if length(dataout) > length(tau)
            TS=1.960*S; %For n > 40
        else
            TS=tau(length(dataout))*S; %For samples of size 3 < n < 40
        end
    end
    %Compare the values of extreme low data points to TS.
    %Begin by determining the NEW value of S times Tau
        S=std(dataout);
        xbar=mean(dataout);
        if length(dataout) > length(tau)
            TS=1.960*S; %For n > 40
        else
            TS=tau(length(dataout))*S; %For samples of size 3 < n < 40
        end
    while abs((min(dataout)-xbar)) > TS 
        dataout=dataout(2:(length(dataout)));
        %Determine the NEW value of S times Tau
        S=std(dataout);
        xbar=mean(dataout);
        if length(dataout) > length(tau)
            TS=1.960*S; %For n > 40
        else
            TS=tau(length(dataout))*S; %For samples of size 3 < n < 40
        end
    end
end
end
%vjp
