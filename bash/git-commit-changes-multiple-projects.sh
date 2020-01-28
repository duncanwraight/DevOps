#!/usr/bin/env bash

RootPath="/my/root/path"

SourceYmlService="service-3"

Services=(
"service-1"
"service-2"
)

Branches=(
"develop"
"master"
)

############# CHANGE NOTHING BELOW THIS POINT #############

# Loop through each service
for i in "${Services[@]}"
do
    ThisServicePath="${RootPath}/${i}"
    SourceYml="${RootPath}/${SourceYmlService}/.gitlab-ci.yml"

    cd $Path
    
    # Loop through each branch
    for branch in "${Branches[@]}"
    do
        git checkout $branch
        cp $SourceYml .
        git add .
        git commit -m "Adding standardised Gitlab CI yml file to service ${i} on ${branch} branch."
        git push origin $branch
    done
done

echo ""

