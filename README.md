# FIFA Soccer Match Classification Models

## Overview
This repository contains data obtained from the *European Soccer Database* on Kaggle. For more information on the original source of the data, the following is a link to the kaggle database: https://www.kaggle.com/hugomathien/soccer. The purpose of these models is to attempt to accuractely predict the outcomes of FIFA soccer matches. I completed a similar project in my last semester of my undergrad, and I wanted to expand upon that model and try to create something of my own.

## Feature Engineering
There were four features created to enhance the accuracy of the model. A win streak variable was created for the home and away team. This variable counts the consecutive number of games the team has won prior to the current match. These features were the most important for the model.

A team rating feature was also created. This variable represents the average team's overall rating. To find the overall rating of each team, the average of the lineup for each team was taken by transferring the appropriate rating (there are multiple ratings for each player, so the release date of the rating is important) to the final dataset. Interestingly, this variable was not important in determining the best fit for the model.

## Conclusions and Future Work
* Currently, only a gradient boosted tree is fit to the data. Additional models are needed for comparison. The obvious one that comes to mind is a SVM, but I would also enjoy trying my hand at a deep learning model. SVM is the obvious choice since it can output probability estimates. These can be compared to the betting odds of the games.
* I do not have a good working knowledge of soccer. I understand how it is played, but I do not understand the strategies and intricacies of the game (to clarify with an example, I understand what types of some defenses work against types of some offenses in football). I mention all of this because there is a large part of the main dataset that was not considered for the model due to the fact that I could not fully comprehend them and what they represented. Research needs to be done to better understand these neglected features.
* The variable importance plot for the XGBoost model showed that the win streaks of the home and away teams were the most influential features in the model. The variable was made to serve as some type of "momentum" indicator. However, I am still trying to conclude why these models are so important. In my research, I came across a paper that proves that bias exists when streaks are determined on past data. The paper is titled *Surprised by the Gambler's and Hot Hand Fallacies? A Truth in the Law of Small Numbers* and it can be found at https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2627354.
* It would be beneficial to add some exploratory data analysis. It is omitted at the moment since most of this was done in another project. However, since EDA is such an important part of modeling, there are certainly more plots that could be created to help understand some of the correlations and distributions of the data. Furthermore, an ROC Curve needs to be created for the XGBoost model.
* Approximating team's goals for each match would be another interesting project.

## XGBoost
Model acheived an accuracy of 79.5% and an ROC_AUC of nearly 90% (the model predicted the win outcomes with 100% certainty). The home team wins about 43% of the time, and the bookies predict the right outcome approximately 53% of the time. Therefore, this model far surpasses those metrics.

### Metrics
![1](https://github.com/StephenODea54/FIFA-Soccer-Outcomes/blob/main/Plots/Metrics_Plot.png)

### Variable Importance
![2](https://github.com/StephenODea54/FIFA-Soccer-Outcomes/blob/main/Plots/Variable_Importance_Plot.png)

### Confusion Matrix
![3](https://github.com/StephenODea54/FIFA-Soccer-Outcomes/blob/main/Plots/Confusion_Matrix.png)
