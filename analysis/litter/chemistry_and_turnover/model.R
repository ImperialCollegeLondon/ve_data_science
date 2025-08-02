#' ---
#' title: Estimating litter decomposition rates from SAFE data
#'
#' description: |
#'     This R script estimates litter decomposition rates from SAFE data.
#'     The goal is to parameterise the litter theoretical model documented
#'     under /theory/soil/litter_theory.html on the VE website. Currently it
#'     includes leaf and wood litter, and we need to work on reproductive and
#'     root litter later
#'
#' VE_module: Litter
#'
#' author:
#'   - name: Hao Ran Lai
#'
#' status: wip
#'
#' input_files:
#'   - name: Both_litter_decomposition_experiment.xlsx
#'     path: data/primary/litter/
#'     description: |
#'       Litter chemistry and decomposition at SAFE vegetation plots by
#'       Sabine Both et al.
#'       Downloaded from https://doi.org/10.5281/zenodo.3247639
#'   - name: SAFE_WoodDecomposition_Data_SAFEdatabase_2021-06-04.xlsx
#'     path: data/primary/litter/
#'     description: |
#'       Deadwood decay and traits in the SAFE landscape by
#'       Terhi Riutta et al.
#'       Downloaded from https://zenodo.org/records/4899610
#'
#' output_files:
#'
#' package_dependencies:
#'     - tidyverse
#'     - readxl
#'     - greta
#'     - bayesplot
#'
#' usage_notes: |
#'   There is also another dataset
#'   Plowman et al. (2018) https://zenodo.org/records/1220270
#'   but the initial mass was wet weight
#'
#' ---

library(tidyverse)
library(readxl)
library(greta)
library(bayesplot)
library(modelr)



# Data --------------------------------------------------------------------

# Leaf litter ================================================

# litter chemistry
chem_leaf <-
  read_xlsx("data/primary/litter/Both_litter_decomposition_experiment.xlsx",
    sheet = 4,
    skip = 7
  ) %>%
  select(
    code,
    P_mg.g:lignin_recalcitrants
  ) %>%
  mutate_at(vars(P_mg.g:lignin_recalcitrants), as.numeric) %>%
  mutate(
    C.P = C_perc / (P_mg.g / 1000 * 100),
    lignin = lignin_recalcitrants * 0.625 / C_perc
  )

# litter decomposition
litter_leaf <-
  read_xlsx("data/primary/litter/Both_litter_decomposition_experiment.xlsx",
    sheet = 5,
    skip = 7
  ) %>%
  # filter replicate A because only these litter bag had chemistry measured
  filter(replicate == "A") %>%
  # long format for modelling
  select(
    code,
    plot,
    litter_type,
    mesh,
    x0 = weight_t0,
    weight_t1,
    weight_t2,
    weight_t3,
    weight_t4,
    weight_t5,
    weight_t6 = t6_corrected
  ) %>%
  pivot_longer(
    cols = weight_t1:weight_t6,
    names_to = "time_step",
    values_to = "xt",
    names_prefix = "weight_t"
  ) %>%
  mutate(
    weeks = case_match(
      time_step,
      "1" ~ 2,
      "2" ~ 4,
      "3" ~ 6,
      "4" ~ 8,
      "5" ~ 13,
      "6" ~ 24
    ),
    days = weeks * 7,
    plot = as.character(plot),
  ) %>%
  # join chemistry data
  left_join(chem_leaf) %>%
  # remove data without lignin content
  filter(!is.na(lignin_recalcitrants))


# Wood litter ================================================

# wood litter chemistry
chem_wood <-
  # nolint start
  read_xlsx("data/primary/litter/SAFE_WoodDecomposition_Data_SAFEdatabase_2021-06-04.xlsx",
    sheet = 4,
    skip = 5
  ) %>%
  # nolint end
  # calculate C:N and C:P ratios
  mutate(
    C.N = C_total / N_total,
    C.P = C_total / (P_total / 1000 * 100)
  ) %>%
  select(Tag, C_total, C.N, C.P)

# wood litter decomposition
litter_wood_raw <-
  # nolint start
  read_xlsx("data/primary/litter/SAFE_WoodDecomposition_Data_SAFEdatabase_2021-06-04.xlsx",
    sheet = 3,
    skip = 5
  ) %>%
  # nolint end
  filter(SampleType == "Wood") %>%
  group_by(
    SamplingCampaign,
    SamplingDate,
    Block,
    Plot,
    PlotCode,
    Tag
  ) %>%
  mutate(Density_WaterDisplacement = as.numeric(Density_WaterDisplacement)) %>%
  summarise(Density = mean(Density_WaterDisplacement, na.rm = TRUE)) %>%
  group_by(Tag) %>%
  filter(n() > 1) %>%
  ungroup()

litter_wood <-
  litter_wood_raw %>%
  filter(SamplingCampaign == "1st") %>%
  select(-SamplingCampaign) %>%
  left_join(
    litter_wood_raw %>%
      filter(SamplingCampaign != "1st") %>%
      select(
        SamplingDate2 = SamplingDate,
        Tag,
        Density2 = Density
      )
  ) %>%
  filter(!is.na(Density2)) %>%
  mutate(
    t = as.numeric(SamplingDate2 - SamplingDate),
    .keep = "unused"
  ) %>%
  # join chemistry data
  left_join(chem_wood) %>%
  # remove wood with Infinite C:P ratios; they had zero P measurement
  # this is not necessary for now because wood is always classified as
  # structural litter regardless of its C:P ratio, but I want to be safe
  # for the future (not a lot of removal anyways)
  # also remove wood that was not measured in the first census
  filter(
    is.finite(C.P),
    !is.na(Density)
  ) %>%
  # wood lignin C
  # fix at 23% * 0.625 for now,
  # as a guess similar to Arne's plant stoichiometry scripts
  # then converted to lignin C per wood C
  mutate(lignin = 23 * 0.625 / C_total)




# Combine litter dataset ======================================
litter <-
  litter_leaf %>%
  select(
    id = code,
    plot,
    x0,
    xt,
    t = days,
    C.N,
    C.P,
    lignin = lignin_recalcitrants
  ) %>%
  mutate(type = "leaf") %>%
  bind_rows(
    litter_wood %>%
      select(
        id = Tag,
        plot = Plot,
        x0 = Density,
        xt = Density2,
        t,
        C.N,
        C.P,
        lignin
      ) %>%
      mutate(type = "wood")
  )




# Model -------------------------------------------------------------------

# Data
xt <- litter$xt
x0 <- litter$x0
log_x0 <- log(x0)

time <- litter$t

plot <- as.numeric(as.factor(litter$plot))
n_plot <- max(plot)

# indicator variable to let fm of non-leaves be zero
type <- ifelse(litter$type == "leaf", 1, 0)
# index for leaf (= 2) and wood (= 1)
type_id <- as.numeric(as.factor(type))

# C:N ratio
CN <- litter$C.N / 100

# C:P ratio
CP <- litter$C.P / 1000

# lignin content
lignin <- litter$lignin

# parameters and priors
log_sN <- normal(-3, 0.5)
log_sP <- normal(-3, 0.5)
sN <- exp(log_sN)
sP <- exp(log_sP)

logit_fM <- normal(1.73, 0.5)
fM <- ilogit(logit_fM)

log_r_lignin <- normal(-1, 0.5)
r_lignin <- exp(log_r_lignin)

# constrain ks_wood < ks_leaf < km
log_ks <- zeros(max(type_id))
log_ks[1] <- normal(-7, 0.5)
log_ks_diff <- normal(1.5, 0.1)
log_ks[2] <- log_ks[1] + exp(log_ks_diff)
ks <- exp(log_ks)

log_km_diff <- normal(1, 0.1)
log_km <- log_ks[2] + exp(log_km_diff)
km <- exp(log_km)

fm <- (fM - lignin * (sN * CN + sP * CP)) * type
metabolic <- fm * exp(-km * time)
structural <- (1 - fm) * exp(-(ks[type_id] * exp(-r_lignin * lignin) * time))

# random terms
sd_plot <- exponential(1)
z_plot <- normal(0, 1, dim = n_plot)
e_plot <- z_plot * sd_plot

# linear predictor
log_mu <- log_x0 + log(metabolic + structural) + e_plot[plot]

# residual variance
sigma <- exponential(1)

# likelihood
distribution(xt) <- lognormal(log_mu, sigma)

# model
mod <-
  model(
    log_sN, log_sP,
    logit_fM,
    log_r_lignin,
    log_ks,
    log_km,
    sigma,
    sd_plot
  )

draws <- mcmc(
  mod,
  warmup = 2000,
  sampler = hmc(15, 20)
)




# Diagnostics ------------------------------------------------------------

mcmc_trace(draws)
mcmc_intervals(draws)




# Predictions -------------------------------------------------------------

newdat <-
  litter %>%
  group_by(type) %>%
  data_grid(
    x0 = 1,
    time = seq(0, 100 * 7, length.out = 50),
    C.N = mean(C.N),
    C.P = mean(C.P),
    lignin = mean(lignin)
  ) %>%
  ungroup()

x0_new <- newdat$x0
log_x0_new <- log(x0_new)

time_new <- newdat$time

type_new <- ifelse(newdat$type == "leaf", 1, 0)
type_id_new <- as.numeric(as.factor(type_new))

CN_new <- newdat$C.N / 100
CP_new <- newdat$C.P / 1000
lignin_new <- newdat$lignin

fm_new <- (fM - lignin_new * (sN * CN_new + sP * CP_new)) * type_new
metabolic_new <- fm_new * exp(-km * time_new)
structural_new <-
  (1 - fm_new) * exp(-(ks[type_id_new] * exp(-r_lignin * lignin_new) * time_new))

log_mu_new <- log_x0_new + log(metabolic_new + structural_new)
mu_new <- exp(log_mu_new)

mu_sim <- calculate(mu_new, values = draws, nsim = 100)

newdat <- newdat %>%
  mutate(
    mu_hat = apply(mu_sim$mu_new, 2, mean),
    lower = apply(mu_sim$mu_new, 2, quantile, probs = 0.05),
    upper = apply(mu_sim$mu_new, 2, quantile, probs = 0.95)
  )

ggplot(newdat) +
  geom_ribbon(
    aes(time,
      ymin = lower, ymax = upper,
      fill = type
    ),
    alpha = 0.4
  ) +
  geom_line(aes(time, mu_hat, colour = type),
    linewidth = 1
  ) +
  scale_colour_viridis_d(
    option = "turbo",
    begin = 0.9, end = 0.1,
    aesthetics = c("fill", "colour")
  ) +
  labs(
    x = "Days",
    y = "Proportion of remaining mass"
  ) +
  coord_cartesian(
    ylim = c(0.5, 1),
    expand = FALSE
  ) +
  theme_bw()



# Parameter estimate ------------------------------------------------------

# remember to back scale
