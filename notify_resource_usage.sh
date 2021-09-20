 #!/bin/bash
chat_id=""
token=""
interface="eth0" #Network interface
time_report=("07:00" "13:00" "20:00" "23:00")

mem_threshold=90; cpu_threshold=90; disk_threshold=90; inode_threshold=90; #Percent
bwin_threshold=90; bwout_threshold=90; #MB
my_text=""  #String contain alert
ip_sv=$(ip a | grep -w inet | grep -Ev "127.0|192.168" | awk '{print $2}' | head -n 1 | awk -F "/" '{print $1}')


#Detect resource usage
cpu_usage=$(mpstat -P ALL  | grep all | awk '{print $4}' | sed "s/\,/\./g")
mem_usage=$(free -m | awk '/Mem:/ { printf("%3.1f", $3/$2*100) }')
disk_usage=$(df -h / | awk '/\// {print $(NF-1)}' | sed "s/%//g")
inode_usage=$(df -ih / | awk '{print $5}' | sed "s/%//g" | tail -n 1)
bw=$(vnstat -i "$interface" -tr 3)
bw_incoming=$(echo "$bw" | grep rx | awk '{printf "%s %s\t PPS: %s %s", $2, $3, $4, $5}')
bw_outcoming=$(echo "$bw" | grep tx | awk '{printf "%s %s\t PPS: %s %s", $2, $3, $4, $5}')

function telegram_send(){
    curl -X POST "https://api.telegram.org/bot"$token"/sendMessage" -d "chat_id="${chat_id}"&text=${my_text}"
}

function float_ge() {
    perl -e "{if("$1">="$2"){print 1} else {print 0}}"
}

function auto_check() {
    bw_in=$(echo "${bw_incoming}" | grep "Mbit" | awk '{print $1}')
    bw_out=$(echo "${bw_outcoming}" | grep "Mbit" | awk '{print $1}')
    if \
        [[ $(float_ge "${cpu_usage}" "${cpu_threshold}") == 1 ]] || \
        [[ $(float_ge "${mem_usage}" "${mem_threshold}") == 1 ]] || \
        [[ $(float_ge "${disk_usage}" "${disk_threshold}") == 1 ]] || \
        [[ $(float_ge "${inode_usage}" "${inode_threshold}") == 1 ]] || \
        [[ ! -z "${bw_in}" && $(float_ge "${bw_in}" "${bwin_threshold}") == 1 ]] || \
        [[ ! -z "${bw_out}" && $(float_ge "${bw_out}" "${bwout_threshold}") == 1 ]]; then
        my_text=$(echo -e "⚠️ Problem For "${ip_sv}" ⚠️ 

📢 CPU usage: "${cpu_usage}"%
📢 Memory usage: "${mem_usage}"%
📢 Disk usage: "${disk_usage}"%
📢 Inode usage: "${inode_usage}"%
📢 Bandwith usage: 
  ➡️ In: "${bw_incoming}"
  ⬅️ Out: "${bw_outcoming}"
")
    fi
    telegram_send
}

function daily_report(){
    now=$(date "+%H:%M")
    for i in "${time_report[@]}"
    do
        if [[ "$now" == "$i" ]];
        then
            my_text=$(echo -e "📋 Daily Report For "${ip_sv}" 📋

📢 CPU usage: "${cpu_usage}"%
📢 Memory usage: "${mem_usage}"%
📢 Disk usage: "${disk_usage}"%
📢 Inode usage: "${disk_usage}"%
📢 Bandwith usage: 
  ➡️ In: "${bw_incoming}"
  ⬅️ Out: "${bw_outcoming}"
")
            telegram_send
        fi
    done
    unset cpu_usage; unset cpu_usage; unset disk_usage; unset bw_in; unset bw_out;
    unset inode_usage; unset bw; unset bw_incoming; unset bw_outcoming;
}

function main(){
    auto_check
    daily_report
}

main

