#!/bin/bash

#####################################################################

Creator - Nitin Namdev
---------DevOps Enginner
Use - Create Image for the running Instance
Required - just api key
Version - 1.0.0
Date - 01/08/2022
Platform - IBM Cloud
What is Image - Image is the copy of an instance you can deploy same instace with same configuration with the help of Image.

#####################################################################




instance_choise="$1"

if [[ `dpkg --list | grep -c 'jq '` == 0 ]]; then echo "Downloadign JQ ... " && apt install jq -y; fi
ibmcloud --version 2>/dev/null
if [[ "$?" == 120 ]]
then
    read -p "Firstly Need to install IBM cloud package" input
    if [[ "$input" == 'y' ]]
    then
        curl -fsSL https://clis.cloud.ibm.com/install/linux | sh
        sleep 0.2
        ibmcloud plugin install vpc-infrastructure
    else
        echo "Exiting from the script .. "
        echo "Thanks you"
        exit 0
    fi
fi

if [[ $(ibmcloud is 2>/dev/null; echo $?) == 1 ]]
then 
    read -p "You are not login \nDo you want to login ? [y\n] > " loginchoice
    if [[ "$loginchoice" == 'n' ]]; then exit 0; fi
    if [[ -z "$apikey" ]]
    then
        echo "Please set the api key in variable ..apikey.. "
        echo "you can exit by typing exit or n"
        echo "or enter your api key >> "
        read apikey
        if [[ "$apikey" == 'exit' || "$apikey" == 'n' ]]; then echo "Exitting .. . " && exit 0; fi
    fi
    ibmcloud login --apikey $apikey -r eu-de
    echo -e "Login  success .."
fi
# get the list of the instace 
# get the details of the instance
ins_details(){
    param=${1:-.name}
    details=$(ibmcloud is instances --output json | jq -r ".[]$param")
    echo $details
}

create_image(){
    if [[ -z "$1" || -z "$1" ]]; then echo "Instance name or no boot volume found on this instance .." && exit 0; fi
    instance_name="$1"
    boot_volume_id="$2"
    echo "Creating custom image... "
    image_id=$(ibmcloud is image-create $instance_name --source-volume $boot_volume_id --output json | jq -r .id )
    waiting_image
}

waiting_image(){
    while true ; do
    status=$(ibmcloud is image "$image_id" --output json | jq -r .status)
    if [[ "$status" == 'available' ]]; then echo "Image is ready" && break && exit 0; fi
    sleep 20
    echo "Creating Image . . . "
    done
    echo "Starting Instance"
    ibmcloud is instance-start $instance_id --output json 1>/dev/null
    echo "Instance is started"
}

get_details_of_instance(){
        instance="$1"
        echo " You choose $instance"
        details=$(ibmcloud is instances --output json | jq -r ".[] | select(.name==\"${instance}\") | .boot_volume_attachment.volume.id, .status, .id")
        boot_volume_id=$(echo $details | awk -F' ' '{print $1}')
        status=$(echo $details | awk -F' ' '{print $2}')
        instance_id=$(echo $details | awk -F' ' '{print $3}')
        instance_name=${instance}
}

list_of_intances=`ins_details`
# list_of_intances=$(ins_details "| [.name, .status]")
# list_of_intances="$list_of_intances" | cut -d ","
# echo $test_var
# exit 0
if [[ ! -z "$instance_choise" ]]
then
    get_details_of_instance $instance_choice
else
    echo -e "These are the list of the instaces for custom Image creation - "
    index=1
    for instance in $list_of_intances; do
        echo "$index $instance " 
        (( index = $index + 1 ))
    done
    read -p " Enter you choise : > " instance_choice
    index=1
    for instance in $list_of_intances; do
        if [[ "$instance_choice" == "$index" ]]
        then
            get_details_of_instance $instance
            break
        fi
    (( index = $index + 1 ))
    done
fi
# echo "instance_name = $instance_name instance_id = $instance_id status = $status boot_volume_id = $boot_volume_id"
if [[ "$status" == 'running' ]]
then
    echo "Instance should be stopped for creation of the image .."
    read -p "Do you want to stop the instance ? [ y/n ] > " stop_choice
    if [[ "$stop_choice" == 'n' ]]; then echo "You have to stop the instance before creating the instance exitting script " && exit 0; fi
    if [[ "$stop_choice" == 'y' ]]
    then 
        echo "Stopping Instance ..."
        ibmcloud is -f instance-stop $instance_id --no-wait
        sleep 5
        create_image $instance_name $boot_volume_id
    fi
elif [[ "$status" == 'stopped' ]]
then 
    create_image $instance_name $boot_volume_id
else
    echo "An Error accured maybe instance state is pending "
    exit 1
fi
