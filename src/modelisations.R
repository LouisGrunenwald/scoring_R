library("caret")
library("pROC")
library("ggplot2")
library("magrittr")

setwd("D:/Documents/Cours M2 MoSEF/Projet Scoring/scoring_R/data")
base_AIC <- read.csv("AIC_selection.csv")
base_BIC <- read.csv("BIC_selection.csv")

# Train test Split 

set.seed(31138353) # Set Seed so that same sample can be reproduced in future also
# Now Selecting 75% of data as sample from total 'n' rows of the data  
train_set <- sample.int(n = nrow(base_AIC), size = floor(0.75*nrow(base_AIC)), replace = F)
train_AIC <- base_AIC[train_set, ]
test_AIC  <- base_AIC[-train_set, ]
train_BIC <- base_BIC[train_set, ]
test_BIC  <- base_BIC[-train_set, ]

# Training two models on train set 

logit_AIC <- glm(BAD ~ ., family = binomial(link= "logit"), data=train_AIC)
probit_AIC <- glm(BAD ~ .,  family = binomial(link = "probit"), data=train_AIC)
logit_BIC <- glm(BAD ~ ., family = binomial(link= "logit"), data=train_BIC)
probit_BIC <- glm(BAD ~ .,  family = binomial(link = "probit"), data=train_BIC)

# Did models converge ?
logit_AIC$converged
probit_AIC$converged
logit_BIC$converged
probit_BIC$converged

summary(logit_AIC)
summary(probit_AIC)
summary(logit_BIC)
summary(probit_BIC)

## Deviance Test
p_value_log_AIC = 1-pchisq(logit_AIC$deviance,logit_AIC$df.resid)
p_value_prob_AIC = 1-pchisq(probit_AIC$deviance,probit_AIC$df.resid)
p_value_log_BIC = 1-pchisq(logit_BIC$deviance,logit_BIC$df.resid)
p_value_prob_BIC = 1-pchisq(probit_BIC$deviance,probit_BIC$df.resid)

# Metrics matrix 
data.frame(
  Feature_selected = c("AIC","AIC","BIC","BIC"),
  Model = c("Logit","Probit","Logit","Probit"),
  AIC = c(AIC(logit_AIC),AIC(probit_AIC),AIC(logit_BIC),AIC(probit_BIC)),
  BIC = c(BIC(logit_AIC),BIC(probit_AIC),BIC(logit_BIC),BIC(probit_BIC)),
  test_dev =c(p_value_log_AIC,p_value_prob_AIC,p_value_log_BIC,p_value_prob_BIC)
  )

### Logit models seem to be more efficient than Probit.

###################################################
#                                                 #
#           Features selected AIC                 #
#                                                 #
###################################################

# Models predictions  

predictions_log <- logit_AIC %>% predict(test_AIC,type="response")
predictions_prob <- probit_AIC %>% predict(test_AIC,type="response")

# Model performance

roc(test_AIC$BAD,predictions_log,plot=TRUE,col="blue",print.auc=TRUE)
roc(test_AIC$BAD,predictions_prob,plot=TRUE,add=TRUE,col="red",print.auc=TRUE,print.auc.y = .4)
legend("bottomright", legend=c("logit","probit"), col=c("blue","red"),lty=1,lwd=2,title = "Courbe ROC des modélisations sur le test set AIC")

# How to build a ROC curve ?

computing_metrics <- function(df,pred) {
  threshold_list <- seq(0.01,0.9,by=0.01)
  thre<-c()
  sensit<-c()
  specif<-c()
  preci <- c()
  for (threshold in threshold_list){
    predict = ifelse(pred > threshold, 1, 0)
    pre = precision(table(predict, df$BAD))
    sens = sensitivity(table(predict, df$BAD))
    spe = specificity(table(predict, df$BAD))
    thre <- c(thre,threshold)
    sensit <- c(sensit,sens)
    specif <- c(specif,spe)
    preci <- c(preci,pre)
  }
  temp <-data.frame(threshold =thre,
                         sensitivity = sensit,
                         specificity = specif,
                         precision = preci)
  temp$F1 <- 2 * (temp$precision * temp$sensitivity)/(temp$precision + temp$sensitivity)
  
  return(temp)
}

metrics_log_AIC <- computing_metrics(test_AIC,predictions_log)
metrics_prob_AIC <- computing_metrics(test_AIC,predictions_prob) # This function compute essentials metrics 

# we're looking for the location row of the best F1 of each model
pos_max_log <- which.max(metrics_log_AIC$F1)
pos_max_prob <- which.max(metrics_prob_AIC$F1) 

### Best Threshold seuil
print(metrics_log_AIC[pos_max_log,"threshold"])
print(metrics_prob_AIC[pos_max_prob,"threshold"])

# We are plottting metrics for each models 

ggplot(metrics_log_AIC, aes(metrics_log_AIC$threshold)) +                    # basic graphical object
  geom_line(aes(y=metrics_log_AIC$sensitivity), colour="red") +  # first layer
  geom_line(aes(y=metrics_log_AIC$precision), colour="blue")+
  geom_line(aes(y=metrics_log_AIC$specificity), colour="darkgreen")+
  geom_line(aes(y=metrics_log_AIC$F1), colour="purple",size=1.5)+
  geom_vline(xintercept = metrics_log_AIC[pos_max_log,"threshold"], color="pink", size=1.2, alpha=0.75)+
  theme_minimal() +
  labs(title = "Metrics Logit model (Selected Feature AIC)",x="Threshold", y="Values")+
  scale_colour_manual(breaks=c("Sensitivity", "Precision","Specificity","F1"),values=c("red","blue","darkgreen","purple"))

ggplot(metrics_prob_AIC, aes(metrics_prob_AIC$threshold)) +
  geom_line(aes(y=metrics_prob_AIC$sensitivity), colour="red") + 
  geom_line(aes(y=metrics_prob_AIC$precision), colour="blue")+
  geom_line(aes(y=metrics_prob_AIC$specificity), colour="darkgreen")+
  geom_line(aes(y=metrics_prob_AIC$F1), colour="purple",size=1.5)+
  geom_vline(xintercept = metrics_prob_AIC[pos_max_prob,"threshold"], color="pink", size=1.2, alpha=0.75)+
  theme_minimal() +
  labs(title = "Metrics Probit model (Selected Feature AIC)",x="Threshold", y="Values")+
  scale_colour_manual(breaks=c("Sensitivity", "Precision","Specificity","F1"),values=c("red","blue","darkgreen","purple"))


# Handbuild roc curve
plot(x=1-metrics_log_AIC$specificity,y=metrics_log_AIC$sensitivity)
plot(x=1-metrics_prob_AIC$specificity,y=metrics_prob_AIC$sensitivity)

# Classifiying with the best threshold
test_AIC$predictions_log_f <-ifelse(predictions_log > metrics_log_AIC[pos_max_log,"threshold"], 1, 0)
test_AIC$predictions_prob_f <-ifelse(predictions_prob > metrics_prob_AIC[pos_max_prob,"threshold"], 1, 0)

# Computing confusion Matrix
Conf_mat_log_AIC <- confusionMatrix(table(test_AIC$predictions_log_f,test_AIC$BAD))[2]
Conf_mat_prob_AIC <-confusionMatrix(table(test_AIC$predictions_prob_f,test_AIC$BAD))[2]
Conf_mat_log_AIC

# Features Importances 

a<-data.frame(varImp(logit_AIC, scale = False))
a$Features <- rownames(a)
rownames(a) <- 1:nrow(a)
a
b<- data.frame(varImp(probit_AIC, scale = False))
b$Features <- rownames(b)
rownames(b) <- 1:nrow(b)
b

ggplot(a, aes(x = Features, y = Overall)) +
  geom_bar(stat="identity")+ 
  theme(axis.text.x = element_text(angle = 90, hjust = 1))
ggplot(b, aes(x = Features, y = Overall)) +
  geom_bar(stat="identity")+ 
  theme(axis.text.x = element_text(angle = 90, hjust = 1))

###################################################
#                                                 #
#           Features selected BIC                 #
#                                                 #
###################################################

# Prediction des modèles 

predictions_log <- logit_BIC %>% predict(test_BIC,type="response")
predictions_prob <- probit_BIC %>% predict(test_BIC,type="response")

# Model performance

roc(test_BIC$BAD,predictions_log,plot=TRUE,col="blue",print.auc=TRUE)
roc(test_BIC$BAD,predictions_prob,plot=TRUE,add=TRUE,col="red",print.auc=TRUE,print.auc.y = .4)
legend("bottomright", legend=c("logit","probit"), col=c("blue","red"),lty=1,lwd=2,title = "Courbe ROC des modélisations sur le test set BIC")

# Using another time metrics function to compute them on the BIC dataset
metrics_log_BIC <- computing_metrics(test_BIC,predictions_log)
metrics_prob_BIC <- computing_metrics(test_BIC,predictions_prob)

# Location of the best threshold
pos_max_log <- which.max(metrics_log_BIC$F1)
pos_max_prob <- which.max(metrics_prob_BIC$F1)
### Best Threshold seuil
print(metrics_log_BIC[pos_max_log,"threshold"])
print(metrics_prob_BIC[pos_max_prob,"threshold"])

# Plotting metrics 
ggplot(metrics_log_BIC, aes(metrics_log_BIC$threshold)) +                    # basic graphical object
  geom_line(aes(y=metrics_log_BIC$sensitivity), colour="red") +  # first layer
  geom_line(aes(y=metrics_log_BIC$precision), colour="blue")+
  geom_line(aes(y=metrics_log_BIC$specificity), colour="darkgreen")+
  geom_line(aes(y=metrics_log_BIC$F1), colour="purple",size=1.5)+
  geom_vline(xintercept = metrics_log_BIC[pos_max_log,"threshold"], color="pink", size=1.2, alpha=0.75)+
  theme_minimal() +
  labs(title = "Metrics Logit model (Selected Feature AIC)",x="Threshold", y="Values")+
  scale_colour_manual(breaks=c("Sensitivity", "Precision","Specificity","F1"),values=c("red","blue","darkgreen","purple"))

ggplot(metrics_prob_BIC, aes(metrics_prob_BIC$threshold)) +
  geom_line(aes(y=metrics_prob_BIC$sensitivity), colour="red") + 
  geom_line(aes(y=metrics_prob_BIC$precision), colour="blue")+
  geom_line(aes(y=metrics_prob_BIC$specificity), colour="darkgreen")+
  geom_line(aes(y=metrics_prob_BIC$F1), colour="purple",size=1.5)+
  geom_vline(xintercept = metrics_prob_BIC[pos_max_prob,"threshold"], color="pink", size=1.2, alpha=0.75)+
  theme_minimal() +
  labs(title = "Metrics Probit model (Selected Feature AIC)",x="Threshold", y="Values")+
  scale_colour_manual(breaks=c("Sensitivity", "Precision","Specificity","F1"),values=c("red","blue","darkgreen","purple"))


# Handbuild roc curve

plot(x=1-metrics_log_BIC$specificity,y=metrics_log_BIC$sensitivity,type="l",col="darkgreen")
par(new=TRUE)
plot(x=1-metrics_prob_BIC$specificity,y=metrics_prob_BIC$sensitivity,type="l",col="darkorange")

# Classifiying with the best threshold
test_BIC$predictions_log_f <-ifelse(predictions_log > metrics_log_BIC[pos_max_log,"threshold"], 1, 0)
test_BIC$predictions_prob_f <-ifelse(predictions_prob > metrics_prob_BIC[pos_max_prob,"threshold"], 1, 0)

# Confusion matrix 
Conf_mat_log_BIC <- confusionMatrix(table(test_BIC$predictions_log_f,test_BIC$BAD))[2]
Conf_mat_log_BIC
Conf_mat_prob_BIC <-confusionMatrix(table(test_BIC$predictions_prob_f,test_BIC$BAD))[2]

# Features Importances 

a<-data.frame(varImp(logit_BIC, scale = False))
a$Features <- rownames(a)
rownames(a) <- 1:nrow(a)
a
b<- data.frame(varImp(probit_BIC, scale = False))
b$Features <- rownames(b)
rownames(b) <- 1:nrow(b)
b

ggplot(a, aes(x = Features, y = Overall)) +
  geom_bar(stat="identity")+ 
  theme(axis.text.x = element_text(angle = 90, hjust = 1))
ggplot(b, aes(x = Features, y = Overall)) +
  geom_bar(stat="identity")+ 
  theme(axis.text.x = element_text(angle = 90, hjust = 1))

###################################################
#                                                 #
#                      Fin                        #
#                                                 #
###################################################