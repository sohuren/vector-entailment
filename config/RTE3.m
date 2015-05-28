function [ hyperParams, options, wordMap, labelMap ] = RTE3(expName, dataflag, embDim, dim, topDepth, penult, lambda, composition, bottomDropout, topDropout, collo, dp, gc, adi)
% Configuration for experiments involving the SemEval SICK challenge and ImageFlickr 30k. 

[hyperParams, options] = Defaults();

% Generate an experiment name that includes all of the hyperparameter values that
% are being tuned.
hyperParams.name = [expName, '-', dataflag, '-l', num2str(lambda), '-dim', num2str(dim),...
    '-ed', num2str(embDim), '-td', num2str(topDepth),...
    '-pen', num2str(penult), '-do', num2str(bottomDropout), '-', num2str(topDropout), '-co', num2str(collo),...
    '-comp', num2str(composition), ...
    '-dp', num2str(dp), '-gc', num2str(gc),  '-adi', num2str(adi)];

hyperParams.restartUpdateRuleInTransfer = adi;

hyperParams.parensInSequences = 0;

hyperParams.dataPortion = dp;

hyperParams.dim = dim;
hyperParams.embeddingDim = embDim;

if collo == 1
    hyperParams.vocabPath = ['/scr/nlp/data/glove_vecs/glove.6B.' num2str(embDim) 'd.txt'];
elseif collo == 2
    hyperParams.vocabPath = '/u/nlp/data/senna_embeddings/combined.txt';  
    assert(embDim == 50, 'The Collobert and Weston-sourced vectors only come in dim 50.'); 
elseif collo == 3
    hyperParams.vocabPath = ['/scr/nlp/data/glove_vecs/glove.840B.' num2str(embDim) 'd.txt'];
end

% The number of embedding transform layers. topDepth > 0 means NN layers will be
% added above the embedding matrix. This is likely to only be useful when
% learnWords is false, and so the embeddings do not exist in the same space
% the rest of the constituents do.
hyperParams.useEmbeddingTransform = 1;

% The number of comparison layers. topDepth > 1 means NN layers will be
% added between the RNTN composition layer and the softmax layer.
hyperParams.topDepth = topDepth;

% If set, store embedding matrix gradients as spare matrices, and only apply regularization
% to the parameters that are in use at each step.
hyperParams.largeVocabMode = true;

% The dimensionality of the comparison layer(s).
hyperParams.penultDim = penult;

% Regularization coefficient.
hyperParams.lambda = lambda; % 0.002 works?;

if gc > 0
    hyperParams.clipGradients = true;
    hyperParams.maxGradNorm = gc;
end

% Apply dropout to the top feature vector of each tree, preserving activations
% with this probability. If this is set to 1, dropout is effectively not used.
hyperParams.bottomDropout = bottomDropout;
hyperParams.topDropout = topDropout;

hyperParams = CompositionSetup(hyperParams, composition);
hyperParams.useThirdOrderMerge = false;

hyperParams.loadWords = true;
hyperParams.trainWords = true;

hyperParams.numLabels = [2];

hyperParams.labels = {{'True', 'False'}};
labelMap = cell(1, 1);
labelMap{1} = containers.Map(hyperParams.labels{1}, 1:length(hyperParams.labels{1}));

hyperParams.trainFilenames = {'../data/rte3_train_parsed.tab'};    
hyperParams.splitFilenames = {};    
hyperParams.testFilenames = {'../data/rte3_train_parsed.tab'};

if strcmp(dataflag, 'rte3')
    wordMap = LoadWordMap('../data/pdtb_words.txt');
    hyperParams.vocabName = 'rte3'; 
elseif strcmp(dataflag, 'rte3-transfer')
    wordMap = LoadWordMap('../data/pdtb-rc3_words.txt');
    hyperParams.vocabName = 'rte3rc3'; 
    hyperParams.sourceWordMap = LoadWordMap('../data/snlirc3_words.txt');

end

end
