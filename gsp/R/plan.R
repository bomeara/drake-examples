# This is where you set up your workflow plan,
# a data frame with the steps of your analysis.

data(Produc) # Gross State Product
head(Produc) # ?Produc

# We want to predict "gsp" based on the other variables.
predictors <- setdiff(colnames(Produc), "gsp")

# We will try all combinations of three covariates.
combos <- combn(predictors, 3) %>%
  t() %>%
  as.data.frame(stringsAsFactors = FALSE)
head(combos)

# Use these combinations to generate
# a workflow plan data frame for drake.
# We generate the plan in stages.

# First, we apply the models to the datasets.
# We make a separate `drake` plan for this purpose.
# Let's start by making the target names
targets <- apply(combos, 1, paste, collapse = "_")
head(targets)

# Each target will be a call to `fit_gsp_model()`
# on 3 covariates.
fit_gsp_model("unemp", "year", "pcap", data = Produc) %>%
  summary()

# So we will generate calls to `fit_gsp_model()`
# as commands for the model-fitting part of the plan.
make_gsp_model_call <- function(...){
  args <- list(..., data = quote(Produc))
  quote(fit_gsp_model) %>%
    c(args) %>%
    as.call() %>%
    rlang::expr_text()
}
make_gsp_model_call("state", "year", "pcap", data = Produc)

commands <- purrr::pmap_chr(combos, make_gsp_model_call)
head(commands)

# We create the model-fitting part of our plan
# by combining the targets and commands together in a data frame.
model_plan <- data.frame(
  target = targets,
  command = commands,
  stringsAsFactors = FALSE
)
head(model_plan)

# Judge the models based on the root mean squared prediction error (RMSPE)
commands <- paste0("get_rmspe(", targets, ", data = Produc)")
targets <- paste0("rmspe_", targets)
rmspe_plan <- data.frame(target = targets, command = commands)

# Aggregate all the results together.
rmspe_results_plan <- gather_plan(
  plan = rmspe_plan,
  target = "rmspe",
  gather = "rbind"
)

# Plan some final output.
output_plan <- drake_plan(
  plot = ggsave(filename = file_out("rmspe.pdf"), plot = plot_rmspe(rmspe)),
  report = knit(knitr_in("report.Rmd"), file_out("report.md"), quiet = TRUE)
)

# Put together the whole plan.
whole_plan <- rbind(model_plan, rmspe_plan, rmspe_results_plan, output_plan)
