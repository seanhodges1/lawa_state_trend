#  LAWA State and Trend Analysis

Processing of council water quality monitoring data for the LAWNZ website
has been completed by Horizons Regional Council staff between 2011 and 2015. To
reduce the dependancy on council staff and to increase transparency to
all participants, these scripts have been prepared to automate the STATE
and TREND assessment portion of LAWA's State and Trend Analysis.

To make the data collation component of this script as flexible as possible,
proprietary file formats or RDBMS systems are not used. Instead, data is
accessed using RESTful requests to Council time series servers. These data
can be processed using standard XML libraries provided by many programming
languages.

