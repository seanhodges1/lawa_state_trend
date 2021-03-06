#===================================================================================================
#  LAWA STATE ANALYSIS
#  Horizons Regional Council
#
# 16 September 2014
#
#  Purpose: Water Quality State Analysis Service Definition
#
#  Processing of council water quality monitoring data for the LAWNZ website
#  has been completed by Horizons council staff between 2011 and 2013. To
#  reduce the dependancy on council staff and to increase transparency to
#  all participants, this script file has been prepared to automate the STATE
#  assessment portion of LAWA's State and Trend Analysis.
#
#  To make the data collation component of this script as flexible as possible,
#  proprietary file formats or RDBMS systems are not used. Instead, data is
#  accessed using standards-based requests to Council time series servers that
#  deliver WaterML 2.0 XML files. WaterML 2.0 is an Open Geospatial Consortium
#  standard that encodes water data time series into an XML file. These data
#  can be accessed using standard XML libraries provided by many programming
#  languages.
#
#  Maree Clark
#  Sean Hodges
#  Horizons Regional Council
#===================================================================================================
ANALYSIS<-"STATE"
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
StartYear <- 2010
EndYear <- 2014

#if(!exists(foo, mode="function")) source("lawa_state_functions.R")

#/* -===Include required function libraries===- */ 


source("lawa_state_functions.R")

#/* -===Global variable/constant definitions===- */ 
vendor <- c("52NORTH","AQUATIC","HILLTOP","KISTERS")


#/* -===Local variable/constant definitions===- */
wqparam <- c("BDISC","TURB","PH","NH4","TON","TN","DRP","TP","ECOLI") 
#wqparam <- c("BDISC") 
tss <- 3  # tss = time series server
#tss_url <- "http://hilltopdev.horizons.govt.nz/lawa2014.hts?"
tss_url <- "http://hilltopdev.horizons.govt.nz:8080/lawa2015.lawa?"

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


cat("LAWA Water QUality State Analysis\n","Number of sites returned:",length(s))


# -=== WQ PARAMETERS ===-
#requestData(vendor[tss],tss_url,"service=Hilltop&request=Reset")
for(i in 1:length(wqparam)){
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
  cat("Left Censored data\n")
  
  if(ANALYSIS=="STATE"){
    wqdata_left <- qualifiedValues2(wqdata_cen)
  } else {
    # For TREND, apply leftCensored()
    
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
  }
  # 3. Handle Right censored (>)
  cat("Right Censored data\n")
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
 
  
  #wqdata <- merge(wqdata, l, by.x="SiteName",by.y="Site", all.x=TRUE) # using native sitetable sitenames to match
  wqdata_right$OriginalValue <- wqdata_right$Value 
  wqdata_right$Value <- wqdata_right$i2Values
  wqdata <- merge(wqdata_right, l, by.x="SiteName",by.y="Site", all.x=TRUE) # Using Hilltop sitenames to match site information
  #wqdata$parameter <- wqparam[i]
  
  # Water quality data includes <, > and * at this point. A decision is need here regarding
  # the method for turning these qualified values into a numeric of some form.
  wqdata_q <- wqdata                  # retaining original data retrieved from webservice
  
  
  #wqdata <- qualifiedValues(wqdata)   # processing less than values
  #wqdata <- subset(wqdata,Value>=0)
  
  # Reduce dataset to complete cases only - removes sites that have data in the hilltop
  # files, but are not explicitly included in the LAWA site table.
  ok <- complete.cases(wqdata[,3])
  wqdata <- wqdata[ok,]  
  
  # There are some data that have been provide with duplicate daily values
  #   - values at mid-night and later during the day.
  # To resolve this issue for the moment, we are simply calculating a median
  # daily value.
  
  # Date/times are reduced to Dates with no times, and then the median value for each day
  # is generated, ensuring that all other data is kept for each record.
  
  ## Code here
  
  ### ADD IN THE LAWA SITE TABLE ATTRIBUTES
  
  wqdata_A <- wqdata
  wqdata_A$dayDate <- trunc(wqdata_A$Date,"days")
  
  wqdata_med <- summaryBy(Value~LAWAID+SiteName+parameter+dayDate,
                          id=~ID+Agency+Site_Type+Region+NZREACH+
                            LanduseGroup+AltitudeGroup+Catchment+Frequency+
                            NZTM_X+NZTM_Y+WSGS84_X+WSGS84_Y+Comments+
                            NIWASITE+NZMS260+MFEX+MFEY+Catchment.Name.LAWA+
                            InHilltopFile+UsedInLAWA,
                          data=wqdata_A, 
                          FUN=c(median), na.rm=TRUE, keep.name=TRUE)
  
  # Building dataframe to save at the end of this step 
  if(i==1){
    #lawadata <- wqdata
    lawadata <- wqdata_med
    lawadata_q <- wqdata_q
  } else {
    #lawadata <- rbind(lawadata,wqdata)
    lawadata <- rbind(lawadata,wqdata_med)
    lawadata_q <- rbind(lawadata_q,wqdata_q)
  }   
  
  
  # =======================================================
  # Water Quality State Analyis
  # =======================================================
  
  # All data for the current paramater is passed through to the StateAnalysis
  # Function.
  #   The output of this function is a data.frame with site medians, 
  # with the grouping variables of landuse, altitude, catchment and local
  # local authority name. This data.frame forms the basis for calculating
  # State for each site, based on the median of the last sampled values
  #   This step also excludes those sites that meets the following exclusion
  # criteria:
  #
  # Exclusion criteria
  #   - less than 30 samples for monthly samples
  #   - less than 80 percent of samples for bimonthly/quarterly
  
  
  cat("LAWA Water Quality State Analysis\n",wqparam[i])
  
  print(Sys.time() - x)
  
  cat("\nLAWA Water QUality State Analysis\nCalculating reference quartiles\n")
  
  state <- c("Site","Catchment","Region","NZ")
  level <- c("LandUseAltitude","LandUse","Altitude","None")
  
  sa11 <- StateAnalysis(wqdata,state[1],level[1])
  
  sa21 <- StateAnalysis(wqdata,state[2],level[1])
  sa22 <- StateAnalysis(wqdata,state[2],level[2])
  sa23 <- StateAnalysis(wqdata,state[2],level[3])
  sa24 <- StateAnalysis(wqdata,state[2],level[4])
  
  sa31 <- StateAnalysis(wqdata,state[3],level[1])
  sa32 <- StateAnalysis(wqdata,state[3],level[2])
  sa33 <- StateAnalysis(wqdata,state[3],level[3])
  sa34 <- StateAnalysis(wqdata,state[3],level[4])
  
  sa41 <- StateAnalysis(wqdata,state[4],level[1])
  sa42 <- StateAnalysis(wqdata,state[4],level[2])
  sa43 <- StateAnalysis(wqdata,state[4],level[3])
  sa44 <- StateAnalysis(wqdata,state[4],level[4])
  
  cat("LAWA Water QUality State Analysis\n","Binding ",wqparam[i]," data together for measurement\n")
  
  if(i==1){
    sa <- rbind(sa11,sa21,sa22,sa23,sa24,sa31,sa32,sa33,sa34,sa41,sa42,sa43,sa44)
  } else {
    sa <- rbind(sa,sa11,sa21,sa22,sa23,sa24,sa31,sa32,sa33,sa34,sa41,sa42,sa43,sa44)
  }
  
}

# Housekeeping
# - Saving the lawadata table
save(lawadata,file=paste("//file/herman/r/oa/08/02/2015/Water Quality/ROutput/lawadata",StartYear,"-",EndYear,".RData",sep=""))
save(lawadata_q,file=paste("//file/herman/r/oa/08/02/2015/Water Quality/ROutput/lawadata_q_",StartYear,"-",EndYear,".RData",sep=""))
save(l,file="//file/herman/r/oa/08/02/2015/Water Quality/ROutput/lawa_sitetable.RData")

# - Remove extraneous objects
rm(sa11,sa21,sa22,sa23,sa24,sa31,sa32,sa33,sa34,sa41,sa42,sa43,sa44)

# State Analysis output contains quantiles for each parameter by site.
# - Rename data.frame headings
names(sa) <- c("AltitudeGroup","LanduseGroup","Region","Catchment","SiteName","LAWAID","Parameter","Q0","Q25","Q50","Q75","Q100","N","Scope")
# - Write data.frame to a csv file for inspection
write.csv(sa,file=paste("//file/herman/r/oa/08/02/2015/Water Quality/ROutput/sa",StartYear,"-",EndYear,".csv",sep=""))

cat("LAWA Water QUality State Analysis\nAssigning State Scores\n")
# ' //   In assigning state scores, the routine needs to process each combination of altitude
# ' // and landuse and compare to the National levels for the same combinations.
# ' //   These combinations are:

# ' //   National data set - no factors
# ' //       Each site (all altitude and landuses) compared to overall National medians

# ' //   Single factor comparisons
# ' //       Each upland site (all landuses) compared to upland National medians
# ' //       Each lowland site (all landuses) compared to lowland National medians
# ' //       Each rural site (all altitudes) compared to rural National medians
# ' //       Each forest site (all altitudes) compared to forest National medians
# ' //       Each urban site (all altitudes) compared to urban National medians

# ' //   Multiple factor comparisons
# ' //      For each Altitude
# ' //        Each rural site compared to rural National medians
# ' //        Each forest site compared to forest National medians
# ' //        Each urban site compared to urban National medians

# ' //      For each LandUse
# ' //        Each upland site compared to upland National medians
# ' //        Each lowland site compared to lowland National medians


scope <- c("Site","Catchment","Region") 

for(i in 1:3){
  ss1 <- StateScore(sa,scope[i],"","",wqparam,comparison=1)  
  ss21 <- StateScore(sa,scope[i],"Upland","",wqparam,comparison=2)
  ss22 <- StateScore(sa,scope[i],"Lowland","",wqparam,comparison=2)
  ss31 <- StateScore(sa,scope[i],"","Rural",wqparam,comparison=3)
  ss32 <- StateScore(sa,scope[i],"","Forest",wqparam,comparison=3)
  ss33 <- StateScore(sa,scope[i],"","Urban",wqparam,comparison=3)
  ss411 <- StateScore(sa,scope[i],"Upland","Rural",wqparam,comparison=4)
  ss412 <- StateScore(sa,scope[i],"Upland","Forest",wqparam,comparison=4)
  # The following line will fail if there are no sites with Upland Urban classification
  # Need to put a test into the StateScore function to return an empty dataframe
  ss413 <- StateScore(sa,scope[i],"Upland","Urban",wqparam,comparison=4)
  ss421 <- StateScore(sa,scope[i],"Lowland","Rural",wqparam,comparison=4)
  ss422 <- StateScore(sa,scope[i],"Lowland","Forest",wqparam,comparison=4)
  ss423 <- StateScore(sa,scope[i],"Lowland","Urban",wqparam,comparison=4)
  if(i==1){
    ss <- rbind(ss1,ss21,ss22,ss31,ss32,ss33,ss411,ss412,ss413,ss421,ss422,ss423)
  } else{
    ss <- rbind(ss,ss1,ss21,ss22,ss31,ss32,ss33,ss411,ss412,ss413,ss421,ss422,ss423)
  }
}

# Housekeeping
# - Remove extraneous objects
rm(ss1,ss21,ss22,ss31,ss32,ss33,ss411,ss412,ss413,ss421,ss422,ss423)


write.csv(ss,file=paste("//file/herman/r/oa/08/02/2015/Water Quality/ROutput/state",StartYear,"-",EndYear,".csv",sep=""))



cat("LAWA Water QUality State Analysis\nCompleted assigning State Scores\n")


print(Sys.time() - x)


ss_csv <- read.csv(file=paste("//file/herman/r/oa/08/02/2015/Water Quality/ROutput/state",StartYear,"-",EndYear,".csv",sep=""),header=TRUE,sep=",",quote = "\"")

ss.1 <- subset(ss_csv,Scope=="Region")
ss.1$Location <- ss.1$Region
ss.2 <- subset(ss_csv,Scope=="Catchment")
ss.2$Location <- ss.2$Catchment
ss.3 <- subset(ss_csv,Scope=="Site")
ss.3$Location <- ss.3$LAWAID

ss.4 <- rbind.data.frame(ss.1,ss.2,ss.3)
unique(ss.4$Location)

ss.5 <- ss.4[c(18,8,2,3,11,17,4,15,16)]

write.csv(ss.5,file=paste("//file/herman/r/oa/08/02/2015/Water Quality/ROutput/LAWA_STATE_FINAL_",StartYear,"-",EndYear,".csv",sep=""))
lawadata_without_niwa <- subset(lawadata,Agency!="NIWA")
lawadata_q_without_niwa <- subset(lawadata_q,Agency!="NIWA")

write.csv(lawadata_without_niwa,"//file/herman/r/oa/08/02/2015/Water Quality/ROutput/LAWA_DATA.csv")
write.csv(lawadata_without_niwa,"//file/herman/r/oa/08/02/2015/Water Quality/ROutput/LAWA_RAW_DATA.csv")

setwd(od)
