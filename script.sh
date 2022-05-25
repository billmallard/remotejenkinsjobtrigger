###############################################################################
#   Purpose:   KTrigger Remote Jobs from Jenkins
#   Params:    --Remote_Job_URL, --Remote_Job_Token, --Basic_Auth_Token, --Time_Limit(seconds)
#   Example:   
#   Documentation: 
###############################################################################

#Remote_Job_URL="https://myjenkins.corp.pvt/job/myjob"
#Remote_Job_Token="11b5f3ab29ac89990d880c1a681234567"
#Basic_Auth_Token="c3ZjX3FhX2F1dG8BLAHBLAHBLAH="
Time_Limit=1200 #20 minutes
Time_Used=0

echo "**********************************"
echo "**********************************"
echo "**********************************"
echo "**********************************"

#Parse the URL Parts from the given remote job url
proto="$(echo $Remote_Job_URL | grep :// | sed -e's,^\(.*://\).*,\1,g')"
base="$(echo  $Remote_Job_URL | awk -F/ '{print $3}')"
url="$(echo $Remote_Job_URL | awk -F$proto '{print $2}')"
path="$(echo $url | grep / | cut -d/ -f2-)"
 

#Show the Parsed Values for Debugging
echo "Remote Job Protocol $proto"
echo "Base URL $base"
echo "Remote Job URL $url"
echo "Remote Job Path $path"
echo "Time Limit $Time_Limit"
echo "Time Used $Time_Used"

echo "**********************************"
echo "**********************************"
echo "*FIRST QUERY - TRIGGER THE BUILD**"
echo "**********************************"

#concatenate url we need to trigger the job build
buildUrl="$Remote_Job_URL/build?token=$Remote_Job_Token"

#Output for debugging
echo "Curl Query $buildUrl"

#Send the request to Jenkins to start the job execution
httpResponse=$(curl --insecure -I  $buildUrl -H "Authorization: Basic $Basic_Auth_Token")
#parse the response header and pull the url out that comes back
#need to add in a test for disabled job status and what to do from there
queueUrl="$(echo $httpResponse | grep -Eo '(http|https)://[a-zA-Z0-9./?=_%:-]*'| awk {'print $1'})"

#Output for debugging
echo "Queue Location Returned $queueUrl"
#tail end of the API url we need for call #2
urlTail="api/xml?token=$Remote_Job_Token"

#concatenate url we need to trigger the job build
queueUrl="$queueUrl$urlTail"
echo "Queue URL Concatenated $queueUrl"

#wait 5 seconds to avoid the sleep period
sleep 5s

echo "**********************************"
echo "**********************************"
echo "*SECOND QUERY - GET THE BUILD NUMBER FROM THE QUEUE**"
echo "**********************************"

#Send the request to Jenkins Queue to get the job url in the response
httpResponse=$(curl --insecure --write-out -I $queueUrl -H "Authorization: Basic $Basic_Auth_Token")

echo "**********************************"
echo "httpResponse: $httpResponse"
echo "**********************************"
echo "Testing response - looking for exit status"

#if response contains <waitingItem or <blockedItem then loop and try the query again
strWaiting="<waitingItem"
strBlocked="<blockedItem"

#wait for queue to not be blocked
while echo $httpResponse | grep $strBlocked
do
    echo "Entered the queue blocked status loop. Will try again in 30 seconds to query the queue."
    sleep 30s
    httpResponse=$(curl --insecure --write-out -I $queueUrl -H "Authorization: Basic $Basic_Auth_Token")
    
    Time_Used=$((Time_Used+30))
    echo "Time Used: $Time_Used"

    # if $Time_Used>$Time_Limit
    # then
    #     echo "Blocked Status Queue Job Timeout Exceeded"
    #     break #exit the loop
    # fi
done

#wait for queue to become active
# i=0
while echo $httpResponse | grep $strWaiting
do
    echo "Entered the queue waiting status loop. Will try again in 10 seconds to query the queue."
    sleep 10s
    httpResponse=$(curl --insecure --write-out -I $queueUrl -H "Authorization: Basic $Basic_Auth_Token")
    
    Time_Used=$((Time_Used+30))
    echo "Time Used: $Time_Used"

    # if $i>5
    # then
    #     echo "Waiting Status Queue Timeout Exceeded"
    #     break #exit the loop
    # fi
done

echo "Finished the queue loops"
echo "**********************************"
echo "httpResponse: $httpResponse"
echo "**********************************"

#This is grabbing two urls, split and parse the second one to get the path we need
jobUrl="$(echo $httpResponse | grep -m2 -Eo '(http|https)://[a-zA-Z0-9./?=_%:-]*'| tail -n1)"
#need to cut the base url out and rebuild since it's returning the non-secure url
jobUrl="$(echo $jobUrl| grep / | cut -d/ -f4-)"

#concatenate url we need to trigger the job build
correctedJobUrl="$proto$base/$jobUrl$urlTail="

echo "**********************************"
echo "**********************************"
echo "*THIRD QUERY - POLL THE BUILD UNTIL IT IS DONE - GET SUCCESS OR FAIL**"
echo "**********************************"

echo "Job Url: $correctedJobUrl" 

#Send the request to Jenkins Job to get the status
httpResponse=$(curl --insecure --write-out -I $correctedJobUrl -H "Authorization: Basic $Basic_Auth_Token")
echo "**********************************"
echo "Build Execution Initial httpResponse: $httpResponse"
echo "**********************************"

#wait for job to finish execution
buildStatus="<result>"

# i=0
while ! echo $httpResponse | grep $buildStatus
do
    echo "Entered the build execution loop. Will try again in 30 seconds to query the build."
    sleep 30s
    httpResponse=$(curl --insecure --write-out -I $correctedJobUrl  -H "Authorization: Basic $Basic_Auth_Token")
    # echo "**********************************"
    # echo "Build Execution Loop httpResponse: $httpRif $Time_Used > $Time_Limit
    # echo "**********************************"


    Time_Used=$((Time_Used+30))
    echo "Time Used: $Time_Used"

    # if $Time_Used > $Time_Limit
    # then
    #     echo "Job Timeout Exceeded"
    #     break #exit the loop
    # fi
done

echo "**********************************"
echo "**********************************"
echo "Finished the build loops"
echo "**********************************"
echo "**********************************"


echo "**********************************"
echo "**********************************"
echo "Download Artifacts"
echo "**********************************"
echo "**********************************"

    fileGrep="$(echo $httpResponse  | grep -oP '(?<=<fileName>).*(?=</fileName)')"
    echo "Grep File Name: $fileGrep" 
    

    #really need a for loop here in case of multiple or zero
    fileUrl="artifact/$fileGrep"
    fileUrl="$proto$base/$jobUrl$fileUrl"
    echo "File Download URL: $fileUrl" 

    fileResponse=$(curl --insecure $fileUrl -H "Authorization: Basic $Basic_Auth_Token" --output $fileGrep)

echo "**********************************"
echo "**********************************"
echo "Finished Downloading Artifacts"
echo "**********************************"
echo "**********************************"

desiredResult="<result>SUCCESS</result>"
if echo $httpResponse | grep $desiredResult
then
    echo "Success Found."
    exit 0 #Need to return a value back to Jenkins
else
    echo "Success was not Found. See Previous Output For Details."
    exit 1 #Need to return a value back to Jenkins
fi
