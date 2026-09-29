#!/bin/bash
# Zero-touch bootstrap floor. Everything after the first catalog is owned by
# puppet_agent5 (in every role). Hostname/hostgroup come from EC2 tags; the
# Foreman token comes from SSM and is kept in memory only.
set -u
LOG=/var/log/post_script.log
exec >> "$LOG" 2>&1
[ -f /etc/puppetlabs/bootstrap.env ] && . /etc/puppetlabs/bootstrap.env
FOREMAN_URL="https://admin.puppetlab.com"

# 0. Who am I? EC2 instance metadata (IMDSv2) — own tags
IMDS=http://169.254.169.254/latest
tok=$(curl -s -X PUT "$IMDS/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
tag() { curl -sf -H "X-aws-ec2-metadata-token: $tok" "$IMDS/meta-data/tags/instance/$1"; }
NAME=$(tag Hostname); HOSTGROUP=$(tag Hostgroup)
FQDN="${NAME}.puppetlab.com"
echo "$(date): start ${FQDN} hostgroup=${HOSTGROUP}"
if [ -z "$NAME" ] || [ -z "$HOSTGROUP" ]; then echo "ABORT: Hostname/Hostgroup tags missing"; exit 1; fi

# Already bootstrapped on an earlier boot -> nothing to do
if [ -f "/etc/puppetlabs/puppet/ssl/certs/${FQDN}.pem" ] && systemctl is-enabled puppet >/dev/null 2>&1; then
  echo "$(date): already bootstrapped"; exit 0
fi

# 1. Hostname + /etc/hosts FIRST (everything after this — facter, CSR — reads the name)
hostnamectl set-hostname "$FQDN"
grep -q "^preserve_hostname" /etc/cloud/cloud.cfg && sed -i 's/^preserve_hostname.*/preserve_hostname: true/' /etc/cloud/cloud.cfg || echo "preserve_hostname: true" >> /etc/cloud/cloud.cfg
MYIP=$(curl -s -H "X-aws-ec2-metadata-token: $tok" "$IMDS/meta-data/local-ipv4")
sed -i '/^127\.0\.1\.1[[:space:]]/d' /etc/hosts
sed -i -E "/^127\./ s/[[:space:]]+${FQDN}([[:space:]]|$)/\1/g; /^127\./ s/[[:space:]]+${NAME}([[:space:]]|$)/\1/g" /etc/hosts
sed -i "/^${MYIP}[[:space:]]/d" /etc/hosts
echo "${MYIP} ${FQDN} ${NAME}" >> /etc/hosts
grep -q "^manage_etc_hosts" /etc/cloud/cloud.cfg && sed -i 's/^manage_etc_hosts.*/manage_etc_hosts: false/' /etc/cloud/cloud.cfg || echo "manage_etc_hosts: false" >> /etc/cloud/cloud.cfg

# 2. OS repos + bootstrap packages
sed -i 's/mirror.centos.org/vault.centos.org/g; s/^#\s*baseurl=/baseurl=/g; s/^mirrorlist=/#mirrorlist=/g' /etc/yum.repos.d/CentOS-Base.repo
yum clean all
yum install -y NetworkManager epel-release
yum install -y awscli
systemctl enable --now NetworkManager

# 3. DNS -> LB pair (primary puppetca1 first)
nmcli con mod "System eth0" ipv4.dns "10.0.1.40 10.0.1.10"
nmcli con mod "System eth0" ipv4.ignore-auto-dns yes
nmcli con mod "System eth0" ipv4.dns-options "timeout:1 attempts:2 single-request-reopen"
nmcli con mod "System eth0" ipv4.dns-search ""
nmcli device reapply eth0
nmcli con mod "System eth0" ipv4.dns-search "puppetlab.com"
nmcli device reapply eth0
sleep 3

# 4. puppet-agent package
rpm -q puppet-agent >/dev/null || { yum install -y https://yum.puppet.com/puppet5-release-el-7.noarch.rpm; yum install -y puppet-agent; }

# 5. Foreman registration (token from SSM, memory only)
TOKEN=""
for i in $(seq 1 12); do   # new IAM instance profiles can take a minute to become usable
  TOKEN=$(aws ssm get-parameter --region "$AWS_REGION" --name "$SSM_PARAM" --with-decryption --query Parameter.Value --output text 2>/dev/null) && [ -n "$TOKEN" ] && break
  echo "$(date): waiting for SSM access ($i)"; sleep 10
done
[ -z "$TOKEN" ] && { echo "ABORT: could not read token from SSM"; exit 1; }
AUTH="admin:${TOKEN}"
RB=/opt/puppetlabs/puppet/bin/ruby
hg_id=$(curl -sk -u "$AUTH" "${FOREMAN_URL}/api/hostgroups?search=name=${HOSTGROUP}" | $RB -rjson -e 'r=JSON.parse(STDIN.read)["results"]; puts r.empty? ? "" : r[0]["id"]')
org_id=$(curl -sk -u "$AUTH" "${FOREMAN_URL}/api/organizations" | $RB -rjson -e 'puts JSON.parse(STDIN.read)["results"][0]["id"]')
loc_id=$(curl -sk -u "$AUTH" "${FOREMAN_URL}/api/locations" | $RB -rjson -e 'puts JSON.parse(STDIN.read)["results"][0]["id"]')
[ -z "$hg_id" ] && { echo "ABORT: hostgroup ${HOSTGROUP} not in Foreman"; exit 1; }
if [ "$(curl -sk -o /dev/null -w '%{http_code}' -u "$AUTH" "${FOREMAN_URL}/api/hosts/${FQDN}")" = "200" ]; then
  curl -sk -u "$AUTH" -X PUT -H "Content-Type: application/json" -d "{\"host\":{\"hostgroup_id\":${hg_id}}}" "${FOREMAN_URL}/api/hosts/${FQDN}" >/dev/null
  echo "$(date): already registered, hostgroup set to ${HOSTGROUP}"
else
  curl -sk -u "$AUTH" -X POST -H "Content-Type: application/json" -d "{\"host\":{\"name\":\"${FQDN}\",\"hostgroup_id\":${hg_id},\"organization_id\":${org_id},\"location_id\":${loc_id},\"managed\":false}}" "${FOREMAN_URL}/api/hosts" >/dev/null
  echo "$(date): registered in ${HOSTGROUP}"
fi
unset TOKEN AUTH

# 6. Minimal puppet.conf + CSR (autosign), wait for the cert (noop: no changes yet)
mkdir -p /etc/puppetlabs/puppet
cat > /etc/puppetlabs/puppet/puppet.conf <<CONF
[main]
certname = ${FQDN}
server = puppetmaster.puppetlab.com
masterport = 8142
ca_server = puppetca.puppetlab.com
ca_port = 8141
CONF
for i in $(seq 1 12); do
  /opt/puppetlabs/bin/puppet agent -t --noop --waitforcert 0
  [ -f "/etc/puppetlabs/puppet/ssl/certs/${FQDN}.pem" ] && break
  echo "$(date): waiting for cert ($i)"; sleep 10
done

# 7. First real run; puppet_agent5 takes over (full puppet.conf, base packages, fact, puppet service)
/opt/puppetlabs/bin/puppet agent -t
echo "$(date): complete, puppet exit=$?"
exit 0