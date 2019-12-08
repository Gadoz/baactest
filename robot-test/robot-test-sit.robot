*** Settings ***
Library    RequestsLibrary
*** Variables ***
${URL_POST}    {ROBOT_HOST}
*** Keywords ***
POST API GO TEST
    ${json_string}=    catenate
    ...    {"cid":""}
	${resp_string}=    catenate
	...    {"response_data":[{"project_name":"","account_no":"","transfer_amt":"","post_date":"","brn_name":"","status":"07"}]}
    Create Session    GO    ${URL_POST}
    &{headers}=    Create Dictionary    Content-Type=application/json
    ${resp}=    POST Request    GO    /statesubsidy    data=${json_string}    headers=${headers}
    Log to console    ${resp.text}
    Should Be Equal As Strings    ${resp.status_code}    200
   
*** Test Cases ***
POST API GO TEST
    POST API GO TEST