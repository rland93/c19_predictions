# c19_predictions
A little GPR model for predicting ncov-19 deaths from existing data

This is a little toy model to help me learn a bit more about GPR.

Data is sourced from:
https://covidtracking.com/data/download

It uses these features of the dataset:

'daysSinceStart',
'positiveIncrease',
'deathIncrease',
'hospitalizedCurrently',
'hospitalizedIncrease',
'onVentilatorCurrently',
'inIcuCurrently'

To predict the 'deathIncrease' var p days in advance.

The idea is that if people are admitted to hospital, on ventilators, in the ICU, etc. some deaths will follow.

Please don't actually use this for anything. It's only to help me learn.
