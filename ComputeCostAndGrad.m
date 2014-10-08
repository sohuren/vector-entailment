% Want to distribute this code? Have other questions? -> sbowman@stanford.edu
function [ cost, grad, pred ] = ComputeCostAndGrad(theta, decoder, dataPoint, constWordFeatures, hyperParams)
% Compute cost, gradient, and predicted label for one example.

% Unpack theta
[classifierMatrices, classifierMatrix, classifierBias, ...
    classifierParameters, trainedWordFeatures, compositionMatrices,...
    compositionMatrix, compositionBias, classifierExtraMatrix, ...
    classifierExtraBias, embeddingTransformMatrix, embeddingTransformBias] ...
    = stack2param(theta, decoder);

if hyperParams.trainWords
    wordFeatures = trainedWordFeatures;
else
    wordFeatures = constWordFeatures;
end

DIM = hyperParams.dim;

% Set the number of composition functions
if ~hyperParams.untied
    NUMCOMP = 1;
else
    NUMCOMP = 3;
end

NUMTRANS = size(embeddingTransformMatrix, 3);

leftTree = dataPoint.leftTree;
rightTree = dataPoint.rightTree;
trueRelation = dataPoint.relation;

relationRange = ComputeRelationRange(hyperParams, trueRelation);

% Make sure word features are current
leftTree.updateFeatures(wordFeatures, compositionMatrices, ...
        compositionMatrix, compositionBias, embeddingTransformMatrix, embeddingTransformBias, hyperParams.compNL);
rightTree.updateFeatures(wordFeatures, compositionMatrices, ...
        compositionMatrix, compositionBias, embeddingTransformMatrix, embeddingTransformBias, hyperParams.compNL);

leftFeatures = leftTree.getFeatures();
rightFeatures = rightTree.getFeatures();

% Compute classification tensor layer
if hyperParams.useThirdOrderComparison
    tensorInnerOutput = ComputeInnerTensorLayer(leftFeatures, ...
        rightFeatures, classifierMatrices, classifierMatrix, classifierBias);
    classTensorOutput = hyperParams.classNL(tensorInnerOutput);
else
      tensorInnerOutput = classifierMatrix * [leftFeatures; rightFeatures]...
          + classifierBias;
    classTensorOutput = hyperParams.classNL(tensorInnerOutput);  
end
       
% Run layers forward
extraInputs = zeros(hyperParams.penultDim, hyperParams.topDepth);
extraInnerOutputs = zeros(hyperParams.penultDim, hyperParams.topDepth - 1);
extraInputs(:,1) = classTensorOutput;
for layer = 1:(hyperParams.topDepth - 1) 
    extraInnerOutputs(:,layer) = (classifierExtraMatrix(:,:,layer) ...
                                    * extraInputs(:,layer)) + ...
                                    classifierExtraBias(:,layer);
    extraInputs(:,layer + 1) = hyperParams.classNL(extraInnerOutputs(:,layer));
end
relationProbs = ComputeSoftmaxProbabilities( ...
                    extraInputs(:,hyperParams.topDepth), classifierParameters, relationRange);

% Compute cost
cost = Objective(trueRelation, relationProbs, hyperParams);

% Produce gradient
if nargout > 1    
    % Initialize the gradients
    if hyperParams.trainWords
      localWordFeatureGradients = sparse([], [], [], ...
          size(wordFeatures, 1), size(wordFeatures, 2), 10);
    else
      localWordFeatureGradients = zeros(0); 
    end
      
    
    if hyperParams.useThirdOrder
        localCompositionMatricesGradients = zeros(DIM, DIM, DIM, NUMCOMP);
    else
    	localCompositionMatricesGradients = zeros(0, 0, 0, NUMCOMP);  
    end 
    localCompositionMatrixGradients = zeros(DIM, 2 * DIM, NUMCOMP);
    localCompositionBiasGradients = zeros(DIM, NUMCOMP);
    localEmbeddingTransformMatrixGradients = zeros(DIM, DIM, NUMTRANS);
    localEmbeddingTransformBiasGradients = zeros(DIM, NUMTRANS);
    
    [localSoftmaxGradient, softmaxDelta] = ...
        ComputeSoftmaxGradient (hyperParams, classifierParameters, ...
                                relationProbs, trueRelation,...
                                extraInputs(:,hyperParams.topDepth), relationRange);
    
    % Compute gradients for extra top layers
    [localExtraMatrixGradients, ...
          localExtraBiasGradients, extraDelta] = ...
          ComputeExtraClassifierGradients(classifierExtraMatrix,...
              softmaxDelta, extraInputs, extraInnerOutputs, hyperParams.classNLDeriv);

    if hyperParams.useThirdOrderComparison
        % Compute gradients for classification tensor layer
        [localClassificationMatricesGradients, ...
            localClassificationMatrixGradients, ...
            localClassificationBiasGradients, classifierDeltaLeft, ...
            classifierDeltaRight] = ...
          ComputeTensorLayerGradients(leftFeatures, rightFeatures, ...
              classifierMatrices, classifierMatrix, classifierBias, ...
              extraDelta, hyperParams.classNLDeriv, tensorInnerOutput);
    else
         % Compute gradients for classification first layer
         localClassificationMatricesGradients = zeros(0, 0, 0);  
         [localClassificationMatrixGradients, ...
            localClassificationBiasGradients, classifierDeltaLeft, ...
            classifierDeltaRight] = ...
          ComputeLayerGradients(leftFeatures, rightFeatures, ...
              classifierMatrix, classifierBias, ...
              extraDelta, hyperParams.classNLDeriv, tensorInnerOutput);
    end

    [ upwardWordGradients, ...
      upwardCompositionMatricesGradients, ...
      upwardCompositionMatrixGradients, ...
      upwardCompositionBiasGradients, ...
      upwardEmbeddingTransformMatrixGradients, ...
      upwardEmbeddingTransformBiasGradients ] = ...
       leftTree.getGradient(classifierDeltaLeft, wordFeatures, ...
                            compositionMatrices, compositionMatrix, ...
                            compositionBias,  embeddingTransformMatrix, embeddingTransformBias, ...
                            hyperParams.compNLDeriv, hyperParams);
                      
    if hyperParams.trainWords
      localWordFeatureGradients = localWordFeatureGradients ...
          + upwardWordGradients;
    end
    localCompositionMatricesGradients = localCompositionMatricesGradients...
        + upwardCompositionMatricesGradients;
    localCompositionMatrixGradients = localCompositionMatrixGradients...
        + upwardCompositionMatrixGradients;
    localCompositionBiasGradients = localCompositionBiasGradients...
        + upwardCompositionBiasGradients;
    localEmbeddingTransformMatrixGradients = localEmbeddingTransformMatrixGradients...
        + upwardEmbeddingTransformMatrixGradients;
    localEmbeddingTransformBiasGradients = localEmbeddingTransformBiasGradients...
        + upwardEmbeddingTransformBiasGradients;
                         
    [ upwardWordGradients, ...
      upwardCompositionMatricesGradients, ...
      upwardCompositionMatrixGradients, ...
      upwardCompositionBiasGradients, ...
      upwardEmbeddingTransformMatrixGradients, ...
      upwardEmbeddingTransformBiasGradients ] = ...
       rightTree.getGradient(classifierDeltaRight, wordFeatures, ...
                            compositionMatrices, compositionMatrix, ...
                            compositionBias, embeddingTransformMatrix, ...
                            embeddingTransformBias, hyperParams.compNLDeriv, hyperParams);
    if hyperParams.trainWords
      localWordFeatureGradients = localWordFeatureGradients ...
          + upwardWordGradients;
    end
    localCompositionMatricesGradients = localCompositionMatricesGradients...
        + upwardCompositionMatricesGradients;
    localCompositionMatrixGradients = localCompositionMatrixGradients...
        + upwardCompositionMatrixGradients;
    localCompositionBiasGradients = localCompositionBiasGradients...
        + upwardCompositionBiasGradients;
    localEmbeddingTransformMatrixGradients = localEmbeddingTransformMatrixGradients...
        + upwardEmbeddingTransformMatrixGradients;
    localEmbeddingTransformBiasGradients = localEmbeddingTransformBiasGradients...
        + upwardEmbeddingTransformBiasGradients;
    
    % Pack up gradients
    grad = param2stack(localClassificationMatricesGradients, ...
        localClassificationMatrixGradients, ...
        localClassificationBiasGradients, localSoftmaxGradient, ...
        localWordFeatureGradients, localCompositionMatricesGradients, ...
        localCompositionMatrixGradients, localCompositionBiasGradients, ...
        localExtraMatrixGradients, localExtraBiasGradients, ...
        localEmbeddingTransformMatrixGradients, localEmbeddingTransformBiasGradients);

end

% Compute prediction. Note: This will be in integer, indexing into whichever class set was used
% for this example.
if nargout > 2
    [~, pred] = max(relationProbs);
end

end

