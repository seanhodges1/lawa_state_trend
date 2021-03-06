#===================================================================================================
#  LAWA TREND ANALYSIS
#  Horizons Regional Council
#
# 17 September 2014
#
#  Maree Clark
#  Sean Hodges
#  Horizons Regional Council
#===================================================================================================
ANALYSIS<-"TREND"
# Set working directory
od<-getwd()
setwd("//file/herman/r/oa/08/02/2015/Water Quality/RScript/lawa_state")

# Clean up output folder before starting script.
cleanup <- FALSE
if(cleanup){
  rOutput <- "//file/herman/r/oa/08/02/2015/Water Quality/ROutput"
  files <- list.files(rOutput)
  if(length(files) >0){
    for(i in 1:length(files)){
      file.remove(paste(rOutput,"/",files[i],sep=""))
    }
  }
}

x <- Sys.time()
#Reference Dates
StartYear <- 2005
EndYear <- 2014

#if(!exists(foo, mode="function")) source("lawa_state_functions.R")

#/* -===Include required function libraries===- */ 

source("lawa_state_functions.R")

#/* -===Global variable/constant definitions===- */ 
vendor <- c("52NORTH","AQUATIC","HILLTOP","KISTERS")


#/* -===Local variable/constant definitions===- */
wqparam <- c("BDISC","TURB","PH","NH4","TON","TN","DRP","TP","ECOLI","DIN") 
#wqparam <- c("BDISC") 
tss <- 3  # tss = time series server
# tss_url <- "http://hilltopdev.horizons.govt.nz/lawa2014trend10.hts?"
# tss_url <- "http://hilltopdev.horizons.govt.nz:8080/lawa2015trend10.lawa?"
tss_url <- "http://hilltopdev.horizons.govt.nz:8080/LAWA2015.lawa?"

hts <- c("service=Hilltop",
         "&request=SiteList",
         "&request=MeasurementList",
         "&request=GetData&collection=LAWA_",
         paste("&from=",StartYear,"-01-01&to=",EndYear+1,"-01-01",sep="")
) 
#_52N
#_kqs
#_sos <- c("service=SOS&request=GetObservation&featureOfInterest=","&observedProperty=","&temporalFilter=om:phenomenom,")


#/* -===Subroutine===- 
#// void main(){}
#*/

# Site data request

#l <- SiteTable(databasePathFileName="//ares/waterquality/LAWA/2013/hilltop.mdb",sqlID=2) ## Assumes all sites have hilltop.mdb site names
requestData(vendor[tss],tss_url,"service=Hilltop&request=Reset")
l <- SiteTable(databasePathFileName="//file/herman/R/OA/08/02/2015/MASTER SiteList/lawa_2015.mdb",sqlID=3) ## Allows for different sitenames in hilltop.mdb - requires assessment and population of the database.
r <- requestData(vendor[tss],tss_url,request=paste(hts[1],hts[2],sep=""))
s <- SiteList(r)


# Load Reference data for Trends --- NO LONGER REQUIRED WITH FUNCTIONS FROM TON
#                                --- SNELDER TO IMPUTE CENSORED VALUES 
#trendRules_csv <- read.csv(file=paste("//file/herman/R/OA/08/02/2015/Water Quality/RScript/lawa_state/trendrules.csv",sep=""),header=TRUE,sep=",",quote = "\"")

cat("LAWA Water QUality TREND Analysis\n","Number of sites returned:",length(s))


# -=== WQ PARAMETERS ===-
#requestData(vendor[tss],tss_url,"service=Hilltop&request=Reset")
for(i in 1:length(wqparam)){

  # Deprecated 18-Sep-2015 as censored data handled by functions
  # supplied by Ton Snelder.
  #tr <- subset(trendRules_csv,DefaultMeasurement==wqparam[i] & Trend=="5years" & Rule=="Halve non detect" & UsedInLAWA==TRUE)
  requestData(vendor[tss],tss_url,"service=Hilltop&request=Reset")
  cat("Starting",wqparam[i],"\n")
  r <- readUrl(vendor[tss],tss_url,paste(hts[1],hts[4],wqparam[i],hts[length(hts)],sep=""))
  #r <- requestData(vendor[tss],tss_url,paste(hts[1],hts[4],wqparam[i],hts[length(hts)],sep=""))
  wqdata <- MeasurementList(xmlmdata=r,requestType="Hilltop")
  wqdata$Value <- as.character(wqdata$Value)
  wqdata$parameter <- wqparam[i]
  
  
  # ------------------------
  # Handling censored data
  # ------------------------
  
  #1. Detect censored data
  wqdata_cen <-flagCensoredDataDF(wqdata)
  wqdata_cen$Value <- as.numeric(wqdata_cen$Value)
  
  # Reduce dataset to complete cases only - removes NA's etc
  ok <- complete.cases(wqdata_cen[,3])
  wqdata_cen <- wqdata_cen[ok,]  
  
  # 2. Handle Left Censored (<)
  # For STATE, half value where CenType==Left
  cat("Left Censored\n")
  
  if(exists("wqdata_left")){
    rm(wqdata_left)
  }
  for(x in 1:length(s)){
    
    tmp<-wqdata_cen[wqdata_cen$SiteName==s[x],]
    ok <- complete.cases(tmp[,3])
    tmp <- tmp[ok,]  
    # Only process sites that have data
    if(length(tmp[,1])!=0){
      if(!exists("wqdata_left")){
        
        tmp1<-leftCensored(tmp)
        if(tmp1!=FALSE){
          wqdata_left <- tmp1
          rm(tmp1)
        }
        
      } else {
        tmp_left<-leftCensored(tmp)
        if(tmp_left!=FALSE){
          wqdata_left <- rbind.data.frame(wqdata_left,tmp_left)
        }
      }
      #cat("Found",length(tmp[,1]),"values for",wqparam[i],"at",s[x],"\n")
      
    } else {
      #cat("No",wqparam[i],"at",s[x],"\n")
    }
  }

  # 3. Handle Right censored (>)
  cat("Right Censored\n")
  
  if(exists("wqdata_right")){
    rm(wqdata_right)
  }
  for(x in 1:length(s)){
    
    tmp<-wqdata_left[wqdata_left$SiteName==s[x],]
    ok <- complete.cases(tmp[,3])
    tmp <- tmp[ok,]  
    # Only process sites that have data
    if(length(tmp[,1])!=0){
      if(!exists("wqdata_right")){
        
        wqdata_right<-rightCensored(tmp)
        
      } else {
        tmp_right<-rightCensored(tmp)
        wqdata_right <- rbind.data.frame(wqdata_right,tmp_right)
      }
      #cat("Found",length(tmp[,1]),"values for",wqparam[i],"at",s[x],"\n")
      
    } else {
      #cat("No",wqparam[i],"at",s[x],"\n")
    }
  }
  
  
  # 4. Jitter tied data
  cat("Jitter\n")
  
  if(exists("wqdata_jitter")){
    rm(wqdata_jitter)
  }
  for(x in 1:length(s)){
    
    tmp<-wqdata_right[wqdata_right$SiteName==s[x],]
    ok <- complete.cases(tmp[,3])
    tmp <- tmp[ok,]  
    # Only process sites that have data
    if(length(tmp[,1])!=0){
      #cat("Jitter",s[x],"\n")
      if(!exists("wqdata_jitter")){
        
        wqdata_jitter<-addJitter(tmp)
        
      } else {
        tmp_jitter<-addJitter(tmp)
        wqdata_jitter <- rbind.data.frame(wqdata_jitter,tmp_jitter)
      }
      
    } else {
      #cat("No",wqparam[i],"at",s[x],"\n")
    }
  }
  
  
  #wqdata <- merge(wqdata, l, by.x="SiteName",by.y="Site", all.x=TRUE) # using native sitetable sitenames to match
  wqdata_jitter$OriginalValue <- wqdata_jitter$Value 
  wqdata_jitter$Value <- wqdata_jitter$i3Values
  wqdata <- merge(wqdata_jitter, l, by.x="SiteName",by.y="Site", all.x=TRUE) # Using Hilltop sitenames to match site information
  #wqdata$parameter <- wqparam[i]
  
  wqdata_q <- wqdata                  # retaining original data retrieved from webservice
  
  #wqdata <- merge(wqdata, l, by.x="SiteName",by.y="Site", all.x=TRUE) # using native sitetable sitenames to match
#   wqdata <- merge(wqdata, l, by.x="SiteName",by.y="Site", all.x=TRUE) # Using Hilltop sitenames to match site information
#   wqdata$parameter <- wqparam[i]
#   
  # Reduce dataset to complete cases only - removes sites that have data in the hilltop
  # files, but are not explicitly included in the LAWA site table.
  ok <- complete.cases(wqdata[,3])
  wqdata <- wqdata[ok,]  
  
  # Deprecated 18-Sep-2015 as censored data handled by functions
  # supplied by Ton Snelder.
  #wqdata <- merge(wqdata, tr, by.x="LAWAID",by.y="LAWAID", all.y=TRUE)
  
  ## --- WHAT IS BEING REORDER HERE AND WHY? ---
  # Reorder items in data.frame
  #wqdata <- wqdata[order(wqdata[,1],wqdata[,3]),]

  # Building dataframe to save at the end of this step 
  if(i==1){
    lawadata <- wqdata
    lawadata_q <- wqdata_q
  } else {
    lawadata <- rbind(lawadata,wqdata)
    lawadata_q <- rbind(lawadata_q,wqdata_q)
  }    
  
  
  print(Sys.time() - x)
  
  
}

# Housekeeping
# - Saving the lawadata table
save(lawadata,file=paste("//file/herman/R/OA/08/02/2015/Water Quality/ROutput/trenddata",StartYear,"-",EndYear,".RData",sep=""))
#write.csv(lawadata,"//file/herman/R/OA/08/02/2015/Water Quality/ROutput/LAWA_RAW_DATA_TREND10yr.csv")

save(lawadata_q,file=paste("//file/herman/R/OA/08/02/2015/Water Quality/ROutput/trenddata_q_",StartYear,"-",EndYear,".RData",sep=""))
#save(l,file="//file/herman/R/OA/08/02/2014/ROutput/lawa_sitetable.RData")

# DATA CLEANSE #

#Calculating the Long term LAWA Trends in water quality.

#Reference Dates
StartYear <- 2005
EndYear <- 2014
years <- EndYear - StartYear + 1
StartMonth <- 1
EndMonth <- 12
if(years==5){
  rate<-1
} else{
  rate<-0.9
}
load(file=paste("//file/herman/R/OA/08/02/2015/Water Quality/ROutput/trenddata",StartYear,"-",EndYear,".RData",sep=""))

###################################################################################
#Step 0 Data Summary
###################################################################################
#•  Ensure one value per sampling interval
#•  Calculate the number of samples per sampling interval and select/calculate/
#     determine representative values


lawadata <- samplesByInterval(StartYear,EndYear,StartMonth,EndMonth,lawadata)


df_count <- summaryBy(Value~SiteName+parameter+yearMon,data=lawadata, FUN=c(length), keep.name=TRUE)


multipleResultsByMonth <- subset(df_count,Value>1)


df_value_monthly <- subset(summaryBy(Value~SiteName+parameter+yearMon,data=lawadata,
                                     id=~LAWAID+LanduseGroup+AltitudeGroup+Catchment+Region+Frequency+year+mon+bimon+Qtr+depth,
                                     FUN=c(median), keep.name=TRUE),Frequency=="Monthly")

df_value_bimonthly <- subset(summaryBy(Value~SiteName+parameter+yearBimon,data=lawadata,
                                       id=~LAWAID+LanduseGroup+AltitudeGroup+Catchment+Region+Frequency+year+mon+bimon+Qtr+depth,
                                       FUN=c(median), keep.name=TRUE),Frequency=="Monthly" | Frequency=="Bimonthly")

df_value_quarterly <- subset(summaryBy(Value~SiteName+parameter+yearQtr,data=lawadata,
                                       id=~LAWAID+LanduseGroup+AltitudeGroup+Catchment+Region+Frequency+year+mon+bimon+Qtr+depth,
                                       FUN=c(median), keep.name=TRUE),Frequency=="Monthly" | Frequency=="Bimonthly" | Frequency=="Quarterly")



###################################################################################


require(wq)

#======================================================
#SEASONAL KENDALL ANALYSIS
#======================================================

t <- Sys.time()


######################################################################################################
# Seasonal Kendall for Monthly Sampling for each site, by each parameter

# Returning unique LAWAIDs for processing data subsets
lawa_ids <- as.character(unique(df_value_monthly$LAWAID))

k <- 1 # counter for sites/parameters meeting minimum N
rbindTrendCheck<-FALSE # Flagging condition for rbinding dataframe that keeps track of sites, measurements and checks for trend inclusion
for(i in 1:length(lawa_ids)){

  months<-12
  l <- lawa_ids[i]
  df_value_monthly1 <- subset(df_value_monthly, LAWAID==l)
  parameters <- as.character(unique(df_value_monthly1$parameter))
  # this step is to double check output with TimeTrends
  #Uncomment if needed
  #write.csv(df_value_monthly1,file=paste("c:/data/MWR_2013/2013/ES-00022.csv",sep=""))
  
  lawa <- wqData(data=df_value_monthly1,locus=c(3,5,15),c(2,4),site.order=TRUE,time.format="%Y-%m-%d",type="long")
  #cat(i,lawa_ids[i],"\n")
  x <- tsMake(object=lawa,focus=gsub("-",".",l))
   
  # calculating seasonal Kendall statistics for individual parameters for an individual site

  for(j in 1:length(parameters)){
    ### TREND INCLUSION CRITERIA
    # 1. Count samples in the first or last 12 month periods to compare to entry criteria for trend
    first_year<-length(df_value_monthly1$year[df_value_monthly1$year==StartYear & df_value_monthly1$parameter==parameters[j]])
    last__year<-length(df_value_monthly1$year[df_value_monthly1$year==EndYear & df_value_monthly1$parameter==parameters[j]])
    # 2. Count samples in order to compare to entry criteria for trend
    num_samples <- length(subset(df_value_monthly1,parameter==parameters[j])[,1])
    
    # building dataframe to report out data to assess pass-fails for trend inclusion
    v <- matrix(data=c(l,parameters[j],first_year,last__year,num_samples),nrow=1,ncol=5,byrow=TRUE)
    if(!rbindTrendCheck){ 
      validDataForTrend <-as.data.frame(v,stringsAsFactors=FALSE)
      rbindTrendCheck<-TRUE
    } else {
      validDataForTrend <- rbind(validDataForTrend, as.data.frame(v,stringsAsFactors=FALSE))
    }
    
    # Check Trend Criteria - Assess pass-fail for trends analysis
    PassTrendCriteria <- TrendCriteria(first_year, last__year, num_samples, rate, years, months)
    
    # Processing Trends for sites/parameters pass trend criteria
    if(PassTrendCriteria){
      
      if(length(parameters)==1){
        s<-seaKenLAWA(x,"median")              # x has a different structure where there is only one item
      } else{
        s<-seaKenLAWA(x[,j],"median")
      }
      #cat(i,lawa_ids[i],length(lawa$time),parameters[j],s$p.value,s$sen.slope.pct,"\n")
      #s$sen.slope.pct  #  <---- required for LAWA
      #s$sen.slope      #  <----
      #s$p.value        #  <---- required for LAWA
      
      
      m <-matrix(data=c(l,parameters[j],s$sen.slope.pct,s$sen.slope,s$p.value),nrow=1,ncol=5,byrow=TRUE)
      if(k==1){   # removed i==i condition - causing errors where first site doesn't meet criteria for trend analysis
        seasonalkendall <-as.data.frame(m,stringsAsFactors=FALSE)
        #cat("seasonalkendal dataframe created\n")
      } else {
        seasonalkendall <- rbind(seasonalkendall, as.data.frame(m,stringsAsFactors=FALSE))
        #cat("Appending to seasonalkendall dataframe\n")
      }
      #cat(k,"\n")
      k <- k + 1
    }
  }
  
}

names(seasonalkendall)    <- c("LAWAID","Parameter","Sen.Pct","Sen.Slope","p.value")
names(validDataForTrend)  <- c("LAWAID","Parameter","N.Months.StartYear","N.Months.EndYear","Num.Samples")
validDataForTrend$freq<- "Monthly"

seasonalkendall$Sen.Pct <-as.numeric(as.character(seasonalkendall$Sen.Pct))
seasonalkendall$Sen.Slope <-as.numeric(as.character(seasonalkendall$Sen.Slope))
seasonalkendall$p.value <-as.numeric(as.character(seasonalkendall$p.value))

seasonalkendall$freq<- "Monthly"
trendscores <- calcTrendScore(seasonalkendall)

rm(m)

load(file="//file/herman/R/OA/08/02/2015/Water Quality/ROutput/lawa_sitetable.RData")
trends <- merge(trendscores, l, by.x="LAWAID",by.y="LAWAID",all.x=TRUE) # Using LAWAIDs to join tables
rm(seasonalkendall)
write.csv(trends,file=paste("//file/herman/R/OA/08/02/2015/Water Quality/ROutput/trend_monthly_",StartYear,"-",EndYear,".csv",sep=""))
write.csv(validDataForTrend,file=paste("//file/herman/R/OA/08/02/2015/Water Quality/ROutput/validDataForTrend_monthly_",StartYear,"-",EndYear,".csv",sep=""))

cat("LAWA Water QUality Trend Analysis\nCompleted assigning Trend Results for Monthly Data\n")
cat(paste(k,"Sites/Parameter combinations meet 75 percent sampling occasion requirements\n"))
rm(trends,validDataForTrend)

######################################################################################################
# Seasonal Kendall for Bimonthly Sampling for each site, by each parameter

# Returning unique LAWAIDs for processing data subsets
lawa_ids <- as.character(unique(df_value_bimonthly$LAWAID))

k <- 1 # counter for sites/parameters meeting minimum N
rbindTrendCheck<-FALSE # Flagging condition for rbinding dataframe that keeps track of sites, measurements and checks for trend inclusion
for(i in 1:length(lawa_ids)){
  months<-6
  l <- lawa_ids[i]
  df_value_bimonthly1 <- subset(df_value_bimonthly, LAWAID==l)
  parameters <- as.character(unique(df_value_bimonthly1$parameter))
  # this step is to double check output with TimeTrends
  #Uncomment if needed
  #write.csv(df_value_monthly1,file=paste("c:/data/MWR_2013/2013/ES-00022.csv",sep=""))
  
  lawa <- wqData(data=df_value_bimonthly1,locus=c(3,5,15),c(2,4),site.order=TRUE,time.format="%Y-%m-%d",type="long")
  x <- tsMake(object=lawa,focus=gsub("-",".",l))
  #cat("length(parameters)",length(parameters),"\n")
  #cat(parameters,"\n")
  
  # calculating seasonal Kendall statistics for individual parameters for an individual site
  for(j in 1:length(parameters)){
    ### TREND INCLUSION CRITERIA
    # 1. Count samples in the first or last 12 month periods to compare to entry criteria for trend
    first_year<-length(df_value_bimonthly1$year[df_value_bimonthly1$year==StartYear & df_value_bimonthly1$parameter==parameters[j]])
    last__year<-length(df_value_bimonthly1$year[df_value_bimonthly1$year==EndYear & df_value_bimonthly1$parameter==parameters[j]])
    # 2. Count samples in order to compare to entry criteria for trend
    num_samples <- length(subset(df_value_bimonthly1,parameter==parameters[j])[,1])
    
    # building dataframe to report out data to assess pass-fails for trend inclusion
    v <- matrix(data=c(l,parameters[j],first_year,last__year,num_samples),nrow=1,ncol=5,byrow=TRUE)
    if(!rbindTrendCheck){ 
      validDataForTrend <-as.data.frame(v,stringsAsFactors=FALSE)
      rbindTrendCheck<-TRUE
    } else {
      validDataForTrend <- rbind(validDataForTrend, as.data.frame(v,stringsAsFactors=FALSE))
    }
    
    # Check Trend Criteria - Assess pass-fail for trends analysis
    PassTrendCriteria <- TrendCriteria(first_year, last__year, num_samples, rate, years, months)
    
    # Processing Trends for sites/parameters pass trend criteria
    if(PassTrendCriteria){
      
      if(length(parameters)==1){
        s<-seaKenLAWA(x,"median")              # x has a different structure where there is only one item
      } else{
        s<-seaKenLAWA(x[,j],"median")
      }
      #cat(i,lawa_ids[i],length(lawa$time),parameters[j],s$p.value,s$sen.slope.pct,"\n")
      
      #s$sen.slope.pct  #  <---- required for LAWA
      #s$sen.slope      #  <----
      #s$p.value        #  <---- required for LAWA
      
      
      m <-matrix(data=c(l,parameters[j],s$sen.slope.pct,s$sen.slope,s$p.value),nrow=1,ncol=5,byrow=TRUE)
      if(k==1){   # removed i==i condition - causing errors where first site doesn't meet criteria for trend analysis
        seasonalkendall <-as.data.frame(m,stringsAsFactors=FALSE)
        #cat("seasonalkendal dataframe created\n")
      } else {
        seasonalkendall <- rbind(seasonalkendall, as.data.frame(m,stringsAsFactors=FALSE))
        #cat("Appending to seasonalkendall dataframe\n")
      }
      k <- k + 1
    }
  }
  
}

names(seasonalkendall) <- c("LAWAID","Parameter","Sen.Pct","Sen.Slope","p.value")
names(validDataForTrend)  <- c("LAWAID","Parameter","N.Months.StartYear","N.Months.EndYear","Num.Samples")
validDataForTrend$freq<- "Bimonthly"

seasonalkendall$Sen.Pct <-as.numeric(as.character(seasonalkendall$Sen.Pct))
seasonalkendall$Sen.Slope <-as.numeric(as.character(seasonalkendall$Sen.Slope))
seasonalkendall$p.value <-as.numeric(as.character(seasonalkendall$p.value))

seasonalkendall$freq<- "Bimonthly"
trendscores <- calcTrendScore(seasonalkendall)

rm(m)

load(file="//file/herman/R/OA/08/02/2015/Water Quality/ROutput/lawa_sitetable.RData")
trends <- merge(trendscores, l, by.x="LAWAID",by.y="LAWAID",all.x=TRUE) # Using LAWAIDs to join tables
rm(seasonalkendall)
write.csv(trends,file=paste("//file/herman/R/OA/08/02/2015/Water Quality/ROutput/trend_bimonthly_",StartYear,"-",EndYear,".csv",sep=""))
write.csv(validDataForTrend,file=paste("//file/herman/R/OA/08/02/2015/Water Quality/ROutput/validDataForTrend_bimonthly_",StartYear,"-",EndYear,".csv",sep=""))

cat("LAWA Water QUality Trend Analysis\nCompleted assigning Trend Results for Bimonthly Data\n")
cat(paste(k,"Sites/Parameter combinations meet 75 percent sampling occasion requirements\n"))
rm(trends,validDataForTrend)

######################################################################################################
# Seasonal Kendall for Quarterly Sampling for each site, by each parameter

# Returning unique LAWAIDs for processing data subsets
lawa_ids <- as.character(unique(df_value_quarterly$LAWAID))

k <- 1 # counter for sites/parameters meeting minimum N
rbindTrendCheck<-FALSE # Flagging condition for rbinding dataframe that keeps track of sites, measurements and checks for trend inclusion
for(i in 1:length(lawa_ids)){
  months<-4
  l <- lawa_ids[i]
  df_value_quarterly1 <- subset(df_value_quarterly, LAWAID==l)
  parameters <- as.character(unique(df_value_quarterly1$parameter))
  # this step is to double check output with TimeTrends
  #Uncomment if needed
  #write.csv(df_value_monthly1,file=paste("c:/data/MWR_2013/2013/ES-00022.csv",sep=""))
  
  lawa <- wqData(data=df_value_quarterly1,locus=c(3,5,15),c(2,4),site.order=TRUE,time.format="%Y-%m-%d",type="long")
  x <- tsMake(object=lawa,focus=gsub("-",".",l))
  #cat("length(parameters)",length(parameters),"\n")
  #cat(parameters,"\n")
  
  # calculating seasonal Kendall statistics for individual parameters for an individual site
  for(j in 1:length(parameters)){
    ### TREND INCLUSION CRITERIA
    # 1. Count samples in the first or last 12 month periods to compare to entry criteria for trend
    first_year<-length(df_value_quarterly1$year[df_value_quarterly1$year==StartYear & df_value_quarterly1$parameter==parameters[j]])
    last__year<-length(df_value_quarterly1$year[df_value_quarterly1$year==EndYear & df_value_quarterly1$parameter==parameters[j]])
    # 2. Count samples in order to compare to entry criteria for trend
    num_samples <- length(subset(df_value_quarterly1,parameter==parameters[j])[,1])
    
    # building dataframe to report out data to assess pass-fails for trend inclusion
    v <- matrix(data=c(l,parameters[j],first_year,last__year,num_samples),nrow=1,ncol=5,byrow=TRUE)
    if(!rbindTrendCheck){ 
      validDataForTrend <-as.data.frame(v,stringsAsFactors=FALSE)
      rbindTrendCheck<-TRUE
    } else {
      validDataForTrend <- rbind(validDataForTrend, as.data.frame(v,stringsAsFactors=FALSE))
    }
    
    # Check Trend Criteria - Assess pass-fail for trends analysis
    PassTrendCriteria <- TrendCriteria(first_year, last__year, num_samples, rate, years, months)
    
    # Processing Trends for sites/parameters pass trend criteria
    if(PassTrendCriteria){
      
      if(length(parameters)==1){
        s<-seaKenLAWA(x,"median")              # x has a different structure where there is only one item
      } else{
        s<-seaKenLAWA(x[,j],"median")
      }
      #cat(i,lawa_ids[i],length(lawa$time),parameters[j],s$p.value,s$sen.slope.pct,"\n")
      #s$sen.slope.pct  #  <---- required for LAWA
      #s$sen.slope      #  <----
      #s$p.value        #  <---- required for LAWA
      
      
      m <-matrix(data=c(l,parameters[j],s$sen.slope.pct,s$sen.slope,s$p.value),nrow=1,ncol=5,byrow=TRUE)
      if(k==1){   # removed i==i condition - causing errors where first site doesn't meet criteria for trend analysis
        seasonalkendall <-as.data.frame(m,stringsAsFactors=FALSE)
        #cat("seasonalkendal dataframe created\n")
      } else {
        seasonalkendall <- rbind(seasonalkendall, as.data.frame(m,stringsAsFactors=FALSE))
        #cat("Appending to seasonalkendall dataframe\n")
      }
      k <- k + 1
    }
  }
  
}

names(seasonalkendall) <- c("LAWAID","Parameter","Sen.Pct","Sen.Slope","p.value")
names(validDataForTrend)  <- c("LAWAID","Parameter","N.Months.StartYear","N.Months.EndYear","Num.Samples")
validDataForTrend$freq<- "Quarterly"

seasonalkendall$Sen.Pct <-as.numeric(as.character(seasonalkendall$Sen.Pct))
seasonalkendall$Sen.Slope <-as.numeric(as.character(seasonalkendall$Sen.Slope))
seasonalkendall$p.value <-as.numeric(as.character(seasonalkendall$p.value))

seasonalkendall$freq<- "Quarterly"
trendscores <- calcTrendScore(seasonalkendall)

rm(m)

load(file="//file/herman/R/OA/08/02/2015/Water Quality/ROutput/lawa_sitetable.RData")
trends <- merge(trendscores, l, by.x="LAWAID",by.y="LAWAID",all.x=TRUE) # Using LAWAIDs to join tables
rm(seasonalkendall)
write.csv(trends,file=paste("//file/herman/R/OA/08/02/2015/Water Quality/ROutput/trend_quarterly_",StartYear,"-",EndYear,".csv",sep=""))
write.csv(validDataForTrend,file=paste("//file/herman/R/OA/08/02/2015/Water Quality/ROutput/validDataForTrend_quarterly_",StartYear,"-",EndYear,".csv",sep=""))

cat("LAWA Water QUality Trend Analysis\nCompleted assigning Trend Results for Quarterly Data\n")
cat(paste(k,"Sites/Parameter combinations meet 75 percent sampling occasion requirements\n"))
rm(trends,validDataForTrend)

######################################################################################################


print(Sys.time()-t)
setwd(od)