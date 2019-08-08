function M = ReadMotionData (file)
% reading the csv from a given filename and plot the gyroscope and the accelerometer 
% in two seperate figures. It also marks the touch events as circles
    GYRO_X = 2;
    GYRO_Y = 3;
    GYRO_Z = 4;
    ACC_X = 6;
    ACC_Y = 7;
    ACC_Z = 8;
    M = csvread(file, 2, 0);
    length = size(M,1);
    x_axis = 1:length;
    
    % Plot results
    fig1 = figure;
    plot(x_axis, M(:,GYRO_X))
    hold on
    plot(x_axis, M(:,GYRO_Y))
    plot(x_axis, M(:,GYRO_Z))
    
    % add the ACTION DOWN events to the plot
    indices = find(M(:,9) == 1);
    %returns a Nx1 array
    indices = indices';
    y_values = zeros(1, size(indices,2));
    scatter(indices, y_values);
    title('Gyroscope Values - Right/left/bottom')
    legend({'GYRO_X', 'GYRO_Y', 'GYRO_Z'})
    hold off
    
    %Start the second figure for the acceleration sensor measurements
    fig2 = figure; 
    plot(x_axis, M(:,ACC_X))
    hold on
    plot(x_axis, M(:,ACC_Y))
    plot(x_axis, M(:,ACC_Z))
    scatter(indices, y_values);
    title('Acceleration Values - Right/left/bottom')
    legend({'ACC_X', 'ACC_Y', 'ACC_Z'})
    hold off
    
end
