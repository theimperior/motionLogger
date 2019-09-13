function showMotionData(data, idx, x, y)

    X = 1:48;
    figure1 = figure;
    hold on
    plot (X, data(:,1,idx))
    plot (X, data(:,2,idx))
    plot (X, data(:,3,idx))
    title(sprintf("sampled from dataset, Gyroscope trace of x:%d, y:%d", x, y))
    legend({'GYRO_X', 'GYRO_Y', 'GYRO_Z'})
    hold off
    figure2 = figure;
    hold on
    plot (X, data(:,4,idx))
    plot (X, data(:,5,idx))
    plot (X, data(:,6,idx))
    title(sprintf("sampled from dataset, Accelerometer trace of x:%d, y:%d", x, y))
    legend({'ACC_X', 'ACC_Y', 'ACC_Z'})
    hold off
end