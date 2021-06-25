function [label_prediction, confusion] = oa_analysis_precomputed(root, subject, run, cfg)
% function [label_prediction, confusion] = oa_analysis_precomputed(root, subject, run, cfg)
% performs ocular artefact analysis on a cvep recording file. it looks for
% ocular artefacts from 2 seconds before trial start until 0.5 seconds
% after trial start. this function requires the files to already be
% pre-processed. analysis inspired by [1],[2],[3]
%
% [1] Belkacem, Abdelkader Nasreddine & Hirose, Hideaki & Yoshimura, 
% Natsue & SHIN, DUK & Koike, Yasuharu. (2014). Classification of Four Eye 
% Directions from EEG Signals for Eye-Movement-Based Communication Systems. 
% Journal of Medical and Biological Engineering. 34. 10.5405/jmbe.1596. 
%
% [2] Belkace, Abdelkader Nasreddine, et al. “Online Classification Algorithm 
% for Eye-Movement-Based Communication Systems Using Two Temporal EEG Sensors.” 
% Biomedical Signal Processing and Control, vol. 16, Feb. 2015, pp. 40–47. 
% www.sciencedirect.com, doi:10.1016/j.bspc.2014.10.005.
%
% [3] Belkacem, Abdelkader Nasreddine, et al. “Real-Time Control of a 
% Video Game Using Eye Movements and Two Temporal EEG Sensors.” Computational 
% Intelligence and Neuroscience, 15 Nov. 2015, 
% doi:https://doi.org/10.1155/2015/653639.

%% WARNING: HARD CODED FS=256 NTRIALS = 36;
% offline run: vars
% root = fullfile(filesep, 'Users', 'dimitar', 'Desktop', 'Thesis', 'Experiment_new');
% ft_root = fullfile(root, 'fieldtrip');
% subject = 'sub-11';
% run = 'test_sync_3';
%% VARIABLES

verbose = 0;
lowtresh = 2000; %(maximum coefficient based threshold, ~75 percentile = 1000)'
hightresh = 4000;
lookstart = 0; 
lookend = 2.5; % 2.5 seconds of each trial

if nargin == 4
    lowtresh = cfg.lowtresh;
    hightresh = cfg.hightresh;
end
%% load precomputed data:
data_path = fullfile(root, 'precomputed', strcat(subject, '_', run, '_precomupted_nodemeannodetrend.mat'));
data = load(data_path);
features = data.features;
labels = data.labels;
%% reshape data to hold trials
m = reshape(features.m, 36,[]);
d = reshape(features.d, 36,[]);
%% extract only target data ( default: t-2  until t+0.5 from trial start)
ms = m(:, 1+256*lookstart:256*lookend);
ds = d(:, 1+256*lookstart:256*lookend);
%% remove outlier data
deletion = ms < lowtresh | ms > hightresh;
ms(deletion) = 0;
ds(deletion) = 0;
%% predict saccade labels
prediction_criterion = sum(ds,2);
label_prediction = prediction_criterion;
label_prediction(label_prediction > 0) = 1;     % left
label_prediction(label_prediction < 0) = -1;    % right

confusion = [];
confusion.nsaccades = sum(label_prediction ~=0);
%% soft label validation - separate visual speller in 2 halves

label_true_soft = labels;
label_true_soft(label_true_soft < 17 ) = 1;
label_true_soft(label_true_soft > 16 ) = -1;
label_true_soft(label_prediction == 0) = 0;

confusion.soft = oa_label_confusion(label_true_soft, label_prediction, prediction_criterion);
%% verbose prints for soft label
if verbose
    for i=1:36
        fprintf('trial %d ', i);
        if  label_true_soft(i) ~= label_prediction(i)
            fprintf('incorrect, nscacs: %d ', sum(ds(i,:)~=0));
        end
        fprintf('dsum: %f', sum((ds(i,:))));
        fprintf('\n');
    end
    fprintf('#saccades: %d correct: %d accuracy:%.3f%%\n', sum(label_prediction~=0), correct_soft, acc_soft*100)
end

%% hard statistic
%fprintf('hard stats %s %s\n', sub, run);

label_true_hard = labels;
for i=2:36
    prevlab = labels(i-1);
    currlab = labels(i);
    truedir = floor((prevlab-1)/6) - floor((currlab-1)/6) ; % 2 - 1 = 1 (left)
    if truedir < 0
        label_true_hard(i) = -1;
    elseif truedir > 0
        label_true_hard(i) = 1;
    else
        label_true_hard(i) = 0;
    end
   % fprintf('true dir: %s d-score: %f\n', dir, dpred(i));
end

label_true_hard(label_prediction == 0) = 0;

confusion.hard = oa_label_confusion(label_true_hard, label_prediction, prediction_criterion);

%% verbose prints for soft label
if verbose
    for i=1:36
        fprintf('trial %d ', i);
        if  label_true_hard(i) ~= label_prediction(i)
            fprintf('incorrect, nscacs: %d ', sum(ds(i,:)~=0));
        end
        fprintf('dsum: %f', sum((ds(i,:))));
        fprintf('\n');
    end
    fprintf('#saccades: %d hard correct: %d hard accuracy:%.3f%%\n', sum(label_prediction~=0), correct_hard, acc_hard*100)
end
%% PLOT A PARTICULAR TRIAL
% figure();
% ttrial = 20; 
% plot(d(ttrial,:));
% hold on;
% plot(m(ttrial,:));
% plot(a(ttrial,:));
% xline(256*2.5);
end
