export REGION="${ZONE%-*}"

# step 1
gcloud compute instances create $INSTANCE \
  --zone=$ZONE \
  --machine-type=e2-micro


# step 2

cat << EOF > startup.sh
#! /bin/bash
apt-get update
apt-get install -y nginx
service nginx start
sed -i -- 's/nginx/Google Cloud Platform - '"\$HOSTNAME"'/' /var/www/html/index.nginx-debian.html
EOF

# Create an instance template. Don't use the default machine type. Make sure you specify e2-medium as the machine type and create the Global template.
gcloud compute instance-templates create nginx-template \
  --machine-type=g1-small \
  --metadata-from-file startup-script=startup.sh
  --region $REGION
echo "Instance template created"

#Create a managed instance group based on the template.
gcloud compute instance-groups managed create nginx-group \
  --base-instance-name web-server \
  --size=2 \
  --template nginx-template \
  --region $REGION
echo "Managed instance group created"

gcloud compute instance-groups managed \
        set-named-ports nginx-group \
        --named-ports http:80 \
        --region $REGION
echo "Named ports set"

#Create a firewall rule named as grant-tcp-rule-264 to allow traffic (80/tcp).
gcloud compute firewall-rules create $FIREWALL \
  --allow=tcp:80 \
  --network=default
echo "Firewall rule created"

#Create a health check.
gcloud compute health-checks create http http-basic-check \
  --port=80
echo "Health check created"

#Create a backend service and add your instance group as the backend to the backend service group with named port (http:80).
gcloud compute backend-services create nginx-backend \
  --protocol=HTTP \
  --port-name=http \
  --health-checks=http-basic-check \
  --global
echo "Backend service created"

gcloud compute backend-services add-backend nginx-backend \
  --instance-group=nginx-group \
  --instance-group-region=$REGION \
  --global
echo "Backend service added"

#Create a URL map, and target the HTTP proxy to route the incoming requests to the default backend service.
gcloud compute url-maps create web-map \
  --default-service=nginx-backend
echo "URL map created"

#Create a target HTTP proxy to route requests to your URL map
gcloud compute target-http-proxies create http-lb-proxy \
  --url-map=web-map
echo "Target HTTP proxy created"

#Create a forwarding rule.
gcloud compute forwarding-rules create http-content-rule \
  --global \
  --target-http-proxy=http-lb-proxy \
  --ports=80
echo "Forwarding rule created"

