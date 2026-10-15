# VE validation can borrow concepts from marginal and conditional predictions

We have been discussing how to match empirical data ("observed") to VE
simulation outputs ("predicted") in space and time. Two sources of indecision
remain:

1. What to do when an observation fall outside of Maliau?
2. How to determine if an external site is sufficiently Maliau-like?

Both can be moved forward with the concept of marginal and conditional
predictions from statistical models, so I will briefly explain what they are.

## Marginal and conditional predictions, simplified

Marginal and conditional predictions are core terms in hierarchical or
mixed-effect models or regressions, but I will simplify it to a linear
regression with a single (fixed) predictor.

Consider a simple linear regression:

$$ Y = a + bX , $$

where $Y$ is the
response or output variable, $X$ is the input predictor, $a$ is the intercept,
and $b$ is the effect (slope) of $X$. The error term is ignored here for
brevity.

The normal routine to build a predictive model is:

1. Collect data $Y$ and $X$
2. Fit the regression $Y = a + bX$
3. Predict new $Y$ from new $X$

An example of Step 3 is collect new soil nitrogen $X$ from a new forest site,
and then predict the new forest site's total stand biomass $Y$. This is (akin
to) *conditional* prediction: the predicted value of $Y$ is conditioned on the
site-specific predictor $X$.

When we want to make a new prediction but lacks the input predictor $X$, our
best bet is the intercept-only (null) model:

$$Y = a .$$

This is the *marginal* prediction, in which we marginalise (or average out) over
the unknown values of $X$. In the VE model, which is not a linear regression,
taking the average of output values, $\bar{Y}$ would be roughly equivalent to
marginalising the predictions to a new site without a known input variable.

> [!CAUTION]
> Note that marginalising through $Y = a$ implies setting $X = 0$. In many
> regressions where we center $X$ to have a mean of zero, it does imply that we
> are predicting $Y$ under the mean $X$ condition. In VE or most process-based
> models, however, we do not center the input variables. So the average
> prediction is actually $\bar{Y} = a + b \bar{X}$, where $\bar{X}$ is the mean
> input value. This implies that, for a new validation site without a known
> input, we should match it to the VE outputs from a grid with the average input
> value. This grid does not exist; it is a *counterfactual* grid. At most, we
> can get as close to this hypothetical grid by search for a grid is closest to
> the mean input value. But VE has $>1$ input variables, and searching for a
> grid that is closest to the multivariate mean starts to sound pointless. In
> short, I think simply calculating the average of output values, $\bar{Y}$, is
> our next best justified option.

This concludes my thought on "What to do when an observation fall outside of
Maliau?"

## Define "Maliau-like"

The average prediction above is only a valid best-guess when the new site
resembles Maliau; because marginalisation assumes that the average Maliau
condition is a good approximation of the new site. But how do we quantitatively
delineate that is Maliau-like vs. what is not?

One solution is to define Maliau-like as falling within the environmental space
of Maliau. Consider "Maliau" defined as a multivariate environmental space, then
any site with environmental conditions that fall within this space is considered
Maliau-like. I am only proposing this as a starting point; surely you are
already thinking about counter-examples and caveats. 😁

I'm proposing this way of thinking to link back to marginal--conditional
predictions. In regressions, we are often comfortable to predict new sites when
they sit within the range of our predictors (*interpolation*), but less
comfortable otherwise (*extrapolation*). When we limit validation sites to those
that sit within the Maliau environmental (input) space, then we ensure that
we're doing more interpolation than extrapolation.

This extends to what counts as an extrapolation. When we validate VE outputs
against a site that falls outside of the Maliau grid extent, our instinct says
that it is an extrapolation. I argue that this is not necessarily extrapolation.
A validation site can sit very far from the Maliau Basin, but still has very
similar environmental conditions. Is this interpolation or extrapolation? There
must be other metacommunity processes happening, e.g., historical contingency,
but this far away site is much more Maliau-like than another equally distant
site with a different environment.

I think this section is probably just paraphrasing your gut instincts and what
you already know, but I wanted to formally ground it around $Y = a + bX$ and the
well-established predictive concepts in statistics.
