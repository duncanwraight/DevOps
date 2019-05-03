lbAddresses=(
"cms-svc.marathon.l4lb.thisdcos.directory:3000"
"developments-svc.marathon.l4lb.thisdcos.directory:3000"
"http-proxy.marathon.l4lb.thisdcos.directory:3000"
"publicpage-orchestration-svc.marathon.l4lb.thisdcos.directory:3000"
"web.marathon.l4lb.thisdcos.directory:8080"
"register-interest-svc.marathon.l4lb.thisdcos.directory:8080"
"http-proxy-preview.marathon.l4lb.thisdcos.directory:3000"
"web-preview.marathon.l4lb.thisdcos.directory:8080"
)

endpoints=(
"/api/status"
)

numAttempts=5
count=1

while [ $count -le $numAttempts ]
do

    echo -e "\n=== ATTEMPT ${count}"
    
    for i in "${lbAddresses[@]}"
    do
        endpoint=(${i//-/ })
        echo -e "\nEndpoint: ${endpoint[2]} ${endpoint[3]}"
        curl ${i}/api/status
        echo
    done

    echo -e "\n===================\n"
    count=$[$count+1]

done