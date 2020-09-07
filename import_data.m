clear;

%% GET DATA %%%%%%%%%%%%%%%%
filename = websave('data_ALL', 'https://covidtracking.com/data/download/all-states-history.csv');
data = readtable('data_ALL');

%% DATA PREPROCESSING %%%%%%%
data{:,"dateAsDateTime"} = arrayfun(@convert2date,data{:,"date"});
% days since start
start = min(data{:,"dateAsDateTime"});
subtract_days = @(date) caldiff([start,date],'days');
data{:,"daysSinceStart"} = flip(split(arrayfun(subtract_days, data{:,"dateAsDateTime"}),'days'));
% prune low quality data
data(~ismember(data{:,"dataQualityGrade"},{'A+'}),:) = [];
% prune rows without feature data
features = {'daysSinceStart','positiveIncrease','deathIncrease','hospitalizedCurrently','hospitalizedIncrease','onVentilatorCurrently','inIcuCurrently'};
% remove NaN rows for all features:
for f = features
    data(isnan(data{:,f}),:) = [];
end
% new jersey sucks because they frequently are grouping hospitalizations for 
% multiple days into one single day
data(ismember(data{:,"state"},{'NJ'}),:) = [];
% count data points by state
states_cat = categorical(data{:,'state'});
table(categories(states_cat), countcats(states_cat),'VariableNames',{'State','Training Priors'})


%% Train Model
% It may be a good idea to look through the data to see which states
% actually are keeping track of our predictor variables.
state = 'IN'
data(~ismember(data{:,"state"},{state}),:) = [];
data = data(:, features);
% either set n < height(data) for prototyping or
% n= height(data) for the full dataset
n = height(data);
p = 10;
h = 120;

% create training dataset with pairs:
% (now hospitalized, now icu... etc) <-> (deaths p days in the future)
% we create these pairs for each state because we could not create cross
% pairs for this information. (a patient admitted to ICU in New York will
% not register as a death 14 days later in Colorado)
% start at 1, end at current_day - p
t_data = data(1:(n-p),:);
% start at p + current_day, end at current_day
t_future_deaths = data{(p+1):n,'deathIncrease'};
% add response variable futureDeathIncrease
t_data(:,'futureDeathIncrease') = data((p+1):n,'deathIncrease');

deaths_model = fitrgp(t_data, 'futureDeathIncrease', ...
    'KernelFunction', 'ardmatern52', ...
    'OptimizeHyperparameters',{'Sigma'}, ...
    'HyperparameterOptimizationOptions', ...
    struct('MaxObjectiveEvaluations',h));

%% PLOTS
day = data{:,'daysSinceStart'}.';
day = [day, day(end)+1:(day(end)+p)];
% we pad all y-vals so that either theyre 1:end-14 or 14:end
% and change negative values to zero, because we don't want a night of the
% living dead situation on our hands
[d_pred, d_sd, d_int] = predict(deaths_model,data);
d_pred = [NaN(1,p), d_pred.'];
d_pred = remove_negs(d_pred);
d_sd = [NaN(1,p), d_sd.'];
d_sd = remove_negs(d_sd);
d_int_minus = [NaN(1,p), d_int(:,1).'];
d_int_minus = remove_negs(d_int_minus);
d_int_plus = [NaN(1,p), d_int(:,2).';];
d_int_plus = remove_negs(d_int_plus);
deaths_real = [data{:,'deathIncrease'}.', NaN(1,p)];
deaths_real = remove_negs(deaths_real);

model_outputs = table(day, ...
    deaths_real, ...
    d_pred, ...
    d_int_minus, ...
    d_int_plus, ...
    'VariableNames', ...
    {'day','realDeaths','predictedDeaths','predictedDeaths-',...
    'predictedDeaths+'});
figure();
ax1 = subplot(2,1,1);
plot(model_outputs{:,'day'}, model_outputs{:,'realDeaths'}, '.', 'MarkerSize',10)
title('Death Prediction  ' + string(p) + ' Days Ahead');
hold on
plot(model_outputs{:,'day'}, model_outputs{:,'predictedDeaths'}, '-');

ticks = 0:5:max(model_outputs{:,'day'});
xticks(ticks);
ylabel('No of Deaths');
%%%% Fill CI Vals
int_shadex = [model_outputs{:,'day'} fliplr(model_outputs{:,'day'})];
int_shadey = [model_outputs{:,'predictedDeaths-'} fliplr(model_outputs{:,'predictedDeaths+'})];
% remove NaNs because matplotlib fill doesn't play nice with them
keep_index = ~isnan(int_shadex) & ~isnan(int_shadey);
int_shadex = int_shadex(keep_index);
int_shadey = int_shadey(keep_index);
fill(int_shadex, int_shadey, 'b','FaceAlpha', 0.06, 'EdgeColor', 'None');

xline(max(model_outputs{:,'day'})-p,':',{'Today'});

hold off

legend({'Deaths','Predicted Deaths','95CI region'},'Location','Best');
ax2 = subplot(2,1,2);

semilogy(data{:,'daysSinceStart'}, remove_negs(data{:,'positiveIncrease'}));
title('Predictor Variables (Log Scale)');
xlabel('Days Since ' + string(start));
ylabel('No of Subjects');

hold on
semilogy(data{:,'daysSinceStart'}, remove_negs(data{:,'deathIncrease'}));
semilogy(data{:,'daysSinceStart'}, remove_negs(data{:,'hospitalizedCurrently'}), 'd');
semilogy(data{:,'daysSinceStart'}, remove_negs(data{:,'hospitalizedIncrease'}),'+');
semilogy(data{:,'daysSinceStart'}, remove_negs(data{:,'inIcuCurrently'}));
semilogy(data{:,'daysSinceStart'}, remove_negs(data{:,'onVentilatorCurrently'}));
legend({'Positive Increase', 'Death Increase', 'Hospitalized', 'Hospitalized Increase','In ICU', 'On Ventilator'},'Location','Best');
xline(max(model_outputs{:,'day'})-p,':',{'Today'});
hold off
linkaxes([ax1,ax2],'x');
xticks(ticks)

sgtitle('Death Prediction Model, ' + string(p) + ' Day Lookahead, ' + state)












