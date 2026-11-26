# Cross-module validation metrics

Lai, Hao Ran
2026-11-26

## Background

We need to choose a standard set of validation metrics across VE modules
to compare results. It is easy to select metrics for a variable, but
much harder when for multiple variables or multiple modules because of
vastly different scales. I focus on the latter problem here.

I will refer to “validation metrics” more formally as “scores” from
hereon.

Scoring validations is the last step in the validation workflow.
Ideally, this step fulfils these criteria: - Built on published
packages: less bespoke, less error-prone, more established - The package
can flexibly extend from point forecast to distributional forecast: we
are doing point forecast (scoring point predictions to point
observations), but VE is slightly stochastic, so we want the flexibility
in case we want to score sample predictions to point observations -
Scores should be **proper**, if not strictly proper (more on this later)

These criteria led me to the R package
[`scoringutils`](https://epiforecasts.io/scoringutils/), which builds on
the trusted `scoringRules` package. This family of packages contain
scores that are based on the body of work by Tilmann Gneiting et
al. (e.g., [Gneiting and Raftery
2007](https://doi.org/10.1198/016214506000001437) and [Gneiting
2011](https://doi.org/10.1198/jasa.2011.r10138)), making them highly
defensible.

For point forecasts, the `scoringutils` package defaults to three
scores:

| Score | Formula | Appropriate point forecast | Interpretation |
| ---- | ---- | ---- | ---- |
| Absolute error (AE) | $\lvert y - \hat{y} \rvert$ | Predictive median | Error in the same units as the observation. |
| Squared error (SE) | $(y - \hat{y})^2$ | Predictive mean | Error in squared units; penalises large errors more strongly. |
| Absolute percentage error (APE) | $\lvert y - \hat{y} \rvert / \lvert y \rvert$ | Predictive $\beta$-median with $\beta = -1$ | Relative error; undefined when the observation is zero. Multiply by 100 to express as a percentage. Can become large when the observation is close to zero. |

Here, $y$ is the observation and $\hat{y}$ is the point forecast. Lower
scores are better (negative orientation).

A point forecast can represent different things: the average prediction
(mean), the middle prediction (median), or a so-called $\beta$-median.
The score must match what the forecast represents. Each score is
**proper** for its matching forecast summary. This means that, on
average, the score is lowest when forecasts report that summary of the
predictive distribution. For example, a score designed for the mean
rewards forecasting the mean—not the median. Otherwise, comparisons are
misleading.

## Results
