                    ### LOAD LIBRARIES ###
library(tidyverse)
library(tidymodels)
library(xgboost)
library(Matrix)
library(vip)

                    ### LOAD DATASET ###
dataset <- readRDS("Data/dataset.rds")

### FEATURE ENGINEERING FOR THINGS THAT WONT WORK IN RECIPE
## REMOVE UNWANTED FEATURES
dataset <- dataset %>%
  select(
    -season, -date, -match_api_id, -home_team, -away_team, -name
  )

## CONVERT CHARACTERS TO FACTORS
dataset <- dataset %>%
  mutate_if(is.character, as.factor)


                    ## XGBoost Model
## SPLITTING DATA
set.seed(1)
soccer_split <- initial_split(dataset, strata = match_score)
soccer_train <- training(soccer_split)
soccer_test <- testing(soccer_split)

## MODEL SPECIFICATIONS
xgb_model <- boost_tree(trees = 1000,
                        mtry = tune(),
                        min_n = tune(),
                        tree_depth = tune(),
                        learn_rate = tune(),
                        sample_size = tune(),
                        loss_reduction = tune()) %>%
  set_mode("classification") %>% 
  set_engine("xgboost")

## GRID SPECIFICATIONS
xgb_grid <- grid_latin_hypercube(
  tree_depth(), 
  min_n(), 
  finalize(mtry(), soccer_train),
  learn_rate(),
  loss_reduction(),
  sample_size = sample_prop(),
  size =60)

## WORKFLOW
xgb_workflow <- workflow() %>% 
  add_formula(match_score ~ .) %>%
  add_model(xgb_model)

## FOLDS
soccer_folds <- vfold_cv(soccer_train, v = 5)

## PLEASE PRAY FOR MY PC
doParallel::registerDoParallel(cores = 6)

## TUNE GRID
xgb_grid_results <- tune_grid(
  xgb_workflow,
  resamples = soccer_folds,
  grid = xgb_grid,
  control = control_grid(save_pred = TRUE)
)

## CHECK RESULTS
xgb_grid_results %>% collect_metrics()

xgboost_metrics %>% 
  filter(.metric == "rmse") %>% 
  select(mean, tree_depth, mtry, min_n,learn_rate, loss_reduction, sample_size) %>% 
  pivot_longer(c(tree_depth, mtry, min_n,learn_rate, loss_reduction, sample_size),
               values_to ="value",
               names_to = "parameter") %>% 
  ggplot(aes(value, mean, color = parameter)) +
  geom_point() + facet_wrap(~parameter, scales = "free_x")


## SELECT BEST PARAMETER
show_best(xgb_grid_results, "accuracy")
xgb_best_accuracy <- select_best(xgb_grid_results, "accuracy")

## FINALIZE WORKFLOW
xgb_final_workflow <- finalize_workflow(
  xgb_workflow,
  xgb_best_accuracy)

## FIT TO TEST DATA
xgb_fit <- xgb_final_workflow %>%
  last_fit(soccer_split)

xgb_fit %>%
  collect_metrics()

## METRICS PLOT
xgb_grid_results %>% collect_metrics() -> xgb_metrics

xgb_metrics %>% 
  filter(.metric == "accuracy") %>% 
  select(mean, tree_depth, mtry, min_n,learn_rate, loss_reduction, sample_size) %>% 
  pivot_longer(c(tree_depth, mtry, min_n,learn_rate, loss_reduction, sample_size),
               values_to ="value",
               names_to = "parameter") %>% 
  ggplot(aes(value, mean, color = parameter)) +
  geom_point() + facet_wrap(~parameter, scales = "free_x")

## VIP PLOT
xgb_final_workflow %>%
  fit(data = soccer_train) %>%
  pull_workflow_fit() %>%
  vip(geom = "point")

## CONFUSION MATRIX
xgb_fit %>%
  collect_predictions() %>% 
  conf_mat(match_score, .pred_class) %>%
  autoplot(type = "heatmap")

## SAVE WORKFLOW AND FINAL FIT
saveRDS(xgb_grid_results, "Models/xgb_grid_results.rds")
saveRDS(xgb_final_workflow, "Models/xgb_final_workflow.rds")
saveRDS(xgb_fit, "Models/xgb_fit.rds")