                    ### LIBRARIES ###
library(RSQLite)
library(tidyverse)
library(data.table)

                    ### LOAD SQLITE LIBRARY ###
##Connect

con <- dbConnect(drv=RSQLite::SQLite(), dbname="Data/database.sqlite")

##Getting the tables

tables <- dbListTables(con)
tables <- tables[tables != "sqlite_sequence"]

##Reading in SQL DATA

country = dbReadTable(con, "Country")
league = dbReadTable(con, "League")
matches = dbReadTable(con, "Match")
player = dbReadTable(con, "Player")
player_Attributes = dbReadTable(con, "Player_Attributes")
teams = dbReadTable(con, "Team")
team_attributes = dbReadTable(con, "Team_Attributes")

##Disconnect from Database
dbDisconnect(con)

                    ### DATA CLEANING ###
### SUBSET RELEVANT INFORMATION
dataset <- matches %>%
  select(
    country_id,
    season,
    date:away_team_goal,
    home_player_1:away_player_11
  )

### JOIN DATASET WITH TEAM NAMES, SEASON AND LEAGUE
dataset <- dataset %>%
  left_join(
    teams %>%
      select(team_api_id, team_long_name) %>%
      rename(home_team_api_id = team_api_id,
             home_team = team_long_name)
  ) %>%
  left_join(
    teams %>%
      select(team_api_id, team_long_name) %>%
      rename(away_team_api_id = team_api_id,
             away_team = team_long_name)
  ) %>%
  left_join(
    team_attributes %>%
      mutate(season = 
            ifelse(date == '2010-02-22 00:00:00', "2009/2010", 
            ifelse(date == '2011-02-22 00:00:00', "2010/2011", 
            ifelse(date == '2012-02-22 00:00:00', "2011/2012",
            ifelse(date == '2013-09-20 00:00:00', "2013/2014", 
            ifelse(date == '2014-09-20 00:00:00', "2014/2015", 
            ifelse(date == '2014-09-19 00:00:00', "2014/2015", 
            ifelse(date == '2015-09-10 00:00:00', "2015/2016",
            ifelse(date == '2015-09-20 00:00:00', "2015/2016", NA
                                                                ))))))))) %>%
    select(team_api_id, season, buildUpPlaySpeed:defenceDefenderLineClass) %>%
      rename(home_team_api_id = team_api_id),
    by = c("home_team_api_id", "season")
  ) %>%
  left_join(
    league %>%
    select(country_id, name)
  ) %>%
  select(-country_id, -home_team_api_id, -away_team_api_id)

### CREATE MATCH SCORE COLUMN
dataset <- dataset %>%
  mutate(match_score = ifelse(home_team_goal > away_team_goal,
                              "Win",
                              ifelse(home_team_goal < away_team_goal,
                                     "Loss",
                                     ifelse(home_team_goal == away_team_goal,
                                            "Tie",
                                            NA)))) %>%
  select(-home_team_goal, -away_team_goal)

## DROP NA VALUES
dataset <- dataset %>%
  drop_na()

                    ### FEATURE ENGINEERING ###
                    ### WIN STREAK DATASET ###
## HOME WIN STREAK
home_win_streak <- dataset %>%
  select(home_team, match_score, season, match_api_id) %>%
  group_by(home_team, season) %>%
  mutate(match_score = ifelse(match_score == "Win",
                              1,
                              0),
         home_win_streak = rowid(rleid(match_score)) * match_score) %>%
  ungroup() %>%
  select(match_api_id, home_win_streak)

## AWAY WIN STREAK
away_win_streak <- dataset %>%
  select(away_team, match_score, season, match_api_id) %>%
  group_by(away_team, season) %>%
  mutate(match_score = ifelse(match_score == "Win",
                              1,
                              0),
         away_win_streak = rowid(rleid(match_score)) * match_score) %>%
  ungroup() %>%
  select(match_api_id, away_win_streak)


## COMBINE WIN STREAK DATASETS
win_streak_data <- bind_cols(home_win_streak %>% arrange(match_api_id),
                             away_win_streak %>% arrange(match_api_id)) %>%
  select(-match_api_id...3) %>%
  rename(match_api_id = match_api_id...1)

## COMBINE WINSTREAK DATASET WITH ORIGINAL
dataset <- dataset %>%
  left_join(
    win_streak_data
  )

                    ### TEAM RATINGS DATASET ###
### COMBINE PLAYER DATASET WITH THEIR OVERALL RATING
player_final <- player %>%
  select(player_api_id) %>%
  left_join(
    player_Attributes %>%
      select(player_api_id, date, overall_rating)
  )

### REPLACE DATE WITH SEASON IN THE PLAYER_FINAL DATASET
dataset <- dataset %>%
  mutate(date = as.Date(date))
  
player_final <- player_final %>%
  mutate(date = as.Date(date, format = "%Y-%m-%d"))

## SUBSET DATASET
## CHANGE TO LONG FORMAT SO THERE IS LESS CODE
ratings <- dataset %>%
  select(date, match_api_id, home_player_1:away_player_11) %>%
  pivot_longer(home_player_1:away_player_11, names_to = "player", values_to = "player_api_id") %>%
  left_join(
    player_final,
    by = "player_api_id"
  )

## CALCULATING THE DIFFERENCE IN DAYS BETWEEN THE DATE OF MATCH AND DATE OF PLAYER RATING RELEASE
ratings <- ratings %>%
  mutate(
    diffDays = as.numeric(abs(date.x - date.y))
  )

## GOING TO USE DTPLYR SO THE COMPUTATION IS QUICKER
ratings_DT <- data.table(ratings)

library(dtplyr)
ratings_DT <- ratings_DT %>%
  group_by(match_api_id, player) %>%
  filter(date.x >= date.y) %>%
  mutate(
    min_days = min(diffDays),
    best_date = ifelse(
      diffDays == min_days,
      1,
      0
    )
  ) %>%
  filter(best_date == 1) %>%
  select(match_api_id, player, overall_rating) %>%
  as_tibble()

## CHANGE BACK TO WIDE FORMAT
ratings <- ratings_DT %>%
  group_by(player) %>%
  mutate(row = row_number()) %>%
  select(row, match_api_id, player, overall_rating) %>%
  pivot_wider(names_from = "player", values_from = "overall_rating") %>%
  select(-row)

## CALCULATE TEAM RATING FOR HOME AND AWAY TEAM
ratings <- ratings %>%
  rowwise(match_api_id) %>%
  mutate(
    home_team_rating = mean(c_across(home_player_1:home_player_11)),
    away_team_rating = mean(c_across(away_player_1:away_player_11))
  ) %>%
  select(match_api_id, home_team_rating, away_team_rating)

## COMBINE DATASETS
dataset <- dataset %>%
  left_join(ratings)

## REMOVE PLAYER COLUMNS
dataset <- dataset %>%
  select(-home_player_1, -home_player_2, -home_player_3, -home_player_4, -home_player_5,
         -home_player_6, -home_player_7, -home_player_8, -home_player_9, -home_player_10,
         -home_player_11, -away_player_1, -away_player_2, -away_player_3, -away_player_4, -away_player_5,
         -away_player_6, -away_player_7, -away_player_8, -away_player_9, -away_player_10,
         -away_player_11)

## SAVE DATASET
saveRDS(dataset, "Data/dataset.RDS")
