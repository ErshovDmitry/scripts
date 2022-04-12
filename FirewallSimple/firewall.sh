#!/bin/bash

echo 'Что бы узнать где находится бинарник iptables, набирите команду'
echo 'which iptables'
echo 'which ip6tables'
echo 'which modprobe'
IPT4='/usr/sbin/iptables'
IPT6='/usr/sbin/ip6tables'
Modprob='/usr/sbin/modprobe'

echo 'Сброс всех параметров iptables IPv4'
$IPT4 -F
$IPT4 -X
$IPT4 -t nat -F
$IPT4 -t nat -X
$IPT4 -t mangle -F
$IPT4 -t mangle -X
$IPT4 -t raw -F
$IPT4 -t raw -X

$IPT4 -P INPUT ACCEPT
$IPT4 -P FORWARD ACCEPT
$IPT4 -P OUTPUT ACCEPT

echo 'Сброс всех параметров iptables IPv6'
$IPT6 -F
$IPT6 -X
$IPT6 -t nat -F
$IPT6 -t nat -X
$IPT6 -t mangle -F
$IPT6 -t mangle -X
$IPT6 -t raw -F
$IPT6 -t raw -X

$IPT6 -P INPUT DROP
$IPT6 -P FORWARD DROP
$IPT6 -P OUTPUT DROP

if [[ $1 == stop ]]; then
  exit 0
fi

echo; echo 'Настройки firewall'
echo 'Включаем модули ядра'
$Modprob nf_conntrack

echo 'Блокировка плохого трафика'
$IPT4 -t raw -A PREROUTING -p tcp --tcp-flags ALL NONE -m comment --comment "Блокируем входящие нулевые пакеты" -j DROP
$IPT4 -t mangle -A PREROUTING -m conntrack --ctstate INVALID -m comment --comment "Блокируем входящие не идентифицированные пакеты" -j DROP

echo 'Разрешаем всё что уже получило разрешение для входящего трафика'
$IPT4 -A INPUT -m conntrack --ctstate UNTRACKED -m comment --comment "Разрешаем весь неотслеживаемый входящий трафик" -j ACCEPT
$IPT4 -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -m comment --comment "Разрешим уже разрешённый, входящий трафик." -j ACCEPT

echo 'Разрешаем всё что уже получило разрешение для проходящего трафика'
$IPT4 -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -m comment --comment "Разрешим уже разрешённый, проходящий трафик" -j ACCEPT

echo 'Отключаем отслеживание пакетов от localhost'
$IPT4 -t raw -A PREROUTING -i lo -d 127.0.0.1 -m comment --comment "Не будем отслеживать локальные запросы." -j CT --notrack
$IPT4 -t raw -A OUTPUT -o lo -d 127.0.0.1 -m comment --comment "Не будем отслеживать локальные запросы." -j CT --notrack

echo 'Разрешаем ICMP (ping) и IGMP'
$IPT4 -A INPUT -p igmp -m comment --comment "Разрешим проходящие igmp пакеты" -j ACCEPT
$IPT4 -A INPUT -p icmp --icmp-type echo-request -m comment --comment "Разрешим входящие ICMP (echo-request)" -j ACCEPT

echo 'Выравнивание MTU'
$IPT4 -t mangle -A POSTROUTING -s 192.168.115.0/24 -o ens18 -p tcp --tcp-flags SYN,RST SYN -m comment --comment "Выравнивание MTU" -j TCPMSS --clamp-mss-to-pmtu

echo 'Отключаем отслеживание пакетов для OpenConnect'
$IPT4 -t raw -A PREROUTING -i ens18 -d 217.197.116.89 -p tcp --dport 443 -m comment --comment "Отключаем отслеживание пакетов для OpenConnect" -j CT --notrack

echo 'Разрешаем SSH порт'
$IPT4 -A INPUT -p tcp --dport 32852 -m comment --comment "Разрешаем SSH порт" -j ACCEPT

echo 'Разрешаем интернет для VPN клиентов'
$IPT4 -A FORWARD -s 192.168.115.0/24 -o ens18 -m comment --comment "Разрешаем интернет для VPN клиентов" -j ACCEPT

echo 'Включаем SNAT для VPN клиентов'
$IPT4 -t nat -A POSTROUTING -s 192.168.115.0/24 -o ens18 -m comment --comment "Включаем SNAT для VPN клиентов" -j SNAT --to-source 217.197.116.89

echo 'Запрещаем всё остальное входящие/проходящие'
echo 'На Debian (INPUT DROP) точно работает нормально'
echo 'На Ubuntu возможно придётся указать (INPUT ACCEPT) но это не точно'
$IPT4 -P INPUT DROP
$IPT4 -P FORWARD DROP
