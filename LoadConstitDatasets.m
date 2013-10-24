function [ trainDataset, testDatasets ] = LoadConstitDatasets ...
    (trainFilenames, splitFilenames, testFilenames, wordMap, relationMap)

% trainFilenames: Load these files as training data.
% testFilenames: Load these files as test data.
% splitFilenames: Split these files into train and test data.

PERCENT_USED_FOR_TRAINING = 0.85;

trainDataset = [];
testDatasets = {};

for i = 1:length(trainFilenames)
    disp(['Loading ', trainFilenames{i}])
    dataset = LoadConstitData(trainFilenames{i}, wordMap, relationMap);
    trainDataset = [trainDataset; dataset];
end

for i = 1:length(testFilenames)
    disp(['Loading ', testFilenames{i}])
    dataset = LoadConstitData(testFilenames{i}, wordMap, relationMap);
    testDatasets = [testDatasets{:}, {dataset}];
end

for i = 1:length(splitFilenames)
    disp(['Loading ', splitFilenames{i}])
    dataset = LoadConstitData(splitFilenames{i}, wordMap, relationMap);
    endOfTrainPortion = ceil(length(dataset) * PERCENT_USED_FOR_TRAINING);
    testDatasets = [testDatasets, ...
                    {dataset(endOfTrainPortion + 1:length(dataset))}];
    trainDataset = [trainDataset; dataset(1:endOfTrainPortion)];
end