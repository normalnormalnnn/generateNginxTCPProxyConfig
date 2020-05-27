#!/bin/sh

#ip, port config file.
portFile=$1
file="proxy.conf"

echo "stream {" > $file
echo "" >> $file
echo "    log_format tcp_log '\$remote_addr [\$time_local] '
                     '\$protocol \$status \$bytes_sent \$bytes_received '
                     '\$session_time "\$upstream_addr" '
                     '"\$upstream_bytes_sent" "\$upstream_bytes_received" "\$upstream_connect_time"';" >> $file;
echo "    access_log /var/log/nginx/tcp_access.log tcp_log;" >> $file
echo "    error_log /var/log/nginx/tcp_error.log;" >> $file
echo "" >> $file
echo "    proxy_connect_timeout 2;" >> $file
echo "" >> $file

function valid_ip()
{
    local  ip=$1
    local  stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

declare -a servers;
ipCount=0
while IFS= read -r line
do
	# 获取ip地址。
	if valid_ip $line; 
	then
		if [ $ipCount -eq 0 ]
		then
			unset servers;
			declare -a servers;
		fi

		servers[$ipCount]=$line
		echo ${servers[$ipCount]}
		ipCount=$((ipCount+1))
		continue;
	fi

	ipCount=0
	port=$line

	# config upstream servers.
	upstream="server${port}"
	echo "    upstream ${upstream} {" >> $file

	if [ ${#servers[@]} -gt 1 ]
	then
		count=1
		for ip in "${servers[@]}"
		do
			if [ $count == 1 ]
			then
				echo "        server ${ip}:${port} weight=3 max_fails=2 fail_timeout=10;" >> $file
			else
				echo "        server ${ip}:${port} weight=1 max_fails=2 fail_timeout=10;" >> $file
			fi
			count=$((count+1))
		done
	else
		echo "        server ${servers[0]}:${port};" >> $file
	fi
	

	echo "    }" >> $file
	
	# config local servers.
	echo "    server {" >> $file
	echo "        listen ${port};" >> $file
	echo "        proxy_pass ${upstream};" >> $file
	echo "    }" >> $file
	echo "" >> $file
	echo "" >> $file
done < $portFile

echo "}" >> $file