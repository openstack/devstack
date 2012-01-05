# Uncomment the following to have a log containing all logs together
#local1,local2,local3,local4,local5.*   %SWIFT_LOGDIR%/all.log

# Uncomment the following to have hourly proxy logs for stats processing
#$template HourlyProxyLog,"%SWIFT_LOGDIR%/hourly/%$YEAR%%$MONTH%%$DAY%%$HOUR%"
#local1.*;local1.!notice ?HourlyProxyLog

local1.*;local1.!notice %SWIFT_LOGDIR%/proxy.log
local1.notice           %SWIFT_LOGDIR%/proxy.error
local1.*                ~

local2.*;local2.!notice %SWIFT_LOGDIR%/storage1.log
local2.notice           %SWIFT_LOGDIR%/storage1.error
local2.*                ~

local3.*;local3.!notice %SWIFT_LOGDIR%/storage2.log
local3.notice           %SWIFT_LOGDIR%/storage2.error
local3.*                ~

local4.*;local4.!notice %SWIFT_LOGDIR%/storage3.log
local4.notice           %SWIFT_LOGDIR%/storage3.error
local4.*                ~

local5.*;local5.!notice %SWIFT_LOGDIR%/storage4.log
local5.notice           %SWIFT_LOGDIR%/storage4.error
local5.*                ~
