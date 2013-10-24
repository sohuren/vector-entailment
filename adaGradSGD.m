function [ theta ] = adaGradSGD(theta, options, thetaDecoder, data, hyperParams)

N = length(data);
prevCost = intmax;

for pass = 1:options.numPasses
    numBatches = ceil(N/options.miniBatchSize);
    sumSqGrad = zeros(size(theta));
    randomOrder = randperm(N);
    accumulatedCost = 0;
    
    for batchNo = 0:(numBatches-1)
        beginMiniBatch = (batchNo * options.miniBatchSize+1);
        endMiniBatch = min((batchNo+1) * options.miniBatchSize,N);
        batchInd = randomOrder(beginMiniBatch:endMiniBatch);
        batch = data(batchInd);
        [ cost, grad ] = ComputeFullCostAndGrad(theta, thetaDecoder, batch, hyperParams);
        prevGrad = grad;
        accumulatedCost = accumulatedCost + cost;
        sumSqGrad = sumSqGrad + grad.^2;
        
        % Do adaGrad update
        adaEps = 0.01;
        theta = theta - options.lr * (grad ./ (sqrt(sumSqGrad) + adaEps));
    end
    accumulatedCost = accumulatedCost / numBatches;
    disp(['pass ', num2str(pass), ': ', num2str(accumulatedCost)]);
    if prevCost - accumulatedCost < 10e-6
        disp('Stopped improving.');
        break;
    end
    
    if mod(pass, 5) == 0
        [~, ~, acc] = ComputeFullCostAndGrad(theta, thetaDecoder, data, hyperParams);
        disp(['PER: ', num2str(acc)]);
        if acc == 0
            break;
        end
    end
        
    
end

end