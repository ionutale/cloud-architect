export ZONE=europe-west4-c
export REGION=${ZONE%-*}
export BUCKET_NAME=gs://$DEVSHELL_PROJECT_ID-media-bucket


# 1. Create a storage bucket
gcloud storage buckets create $BUCKET_NAME \
  --location $REGION

cat << EOF > install-web.sh
 #! /bin/bash
 apt update
 apt -y install apache2
 cat <<EOF > /var/www/html/index.html
 <html><body><p>Linux startup script added directly.</p></body></html>
EOF

gsutil cp ./install-web.sh $BUCKET_NAME


# 2. Create a Compute Engine instance
gcloud compute instances create vm-media \
  --zone=$ZONE \
  --machine-type=e2-medium \
  --metadata=startup-script-url=$BUCKET_NAME/install-web.sh \
  --tags=media-server \
  --scopes=https://www.googleapis.com/auth/cloud-platform

# 3. Create a firewall rule
gcloud compute firewall-rules create default-allow-http-80 \
  --allow tcp:80 \
  --source-ranges="0.0.0.0/0" \
  --target-tags=media-server
  
# 4. Verify the setup
