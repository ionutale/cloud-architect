export BUCKET_NAME=qwiklabs-gcp-01-edbe6ce80e51-bucket
export TOPIC_NAME=topic-memories-304
export ZONE=us-central1-c
export REGION=${ZONE%-*}

gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE

PROJECT_ID=$(gcloud config get-value project)
PROJECT_NUMBER=$(gcloud projects list --filter="project_id:$PROJECT_ID" --format='value(project_number)')

SERVICE_ACCOUNT=$(gcloud storage service-agent --project=$PROJECT_ID)

# Create a service account
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member serviceAccount:$SERVICE_ACCOUNT \
  --role roles/pubsub.publisher \
  --role roles/storage.objectViewer \
  --role roles/cloudfunctions.invoker \
  --role roles/cloudfunctions.developer \
  --role roles/cloudfunctions.admin \
  --role roles/iam.serviceAccount.actAs \
  --role role/run.services.create \
  --role role/run.services.update \
  --role roles/run.admin \
  --role roles/iam.serviceAccountUser \
  --role roles/iam.serviceAccountTokenCreator \
  --role roles/eventarc.eventReceiver \
  --role roles/pubsub.publisher 


# Create a storage bucket
gcloud storage buckets create gs://$BUCKET_NAME \
  --location=$REGION

# Create a Pub/Sub topic
gcloud pubsub topics create $TOPIC_NAME

# Create a Cloud Function
gcloud functions deploy memories-thumbnail-creator \
  --gen2 \
  --runtime=nodejs20 \
  --source=./ \
  --region=$REGION \
  --trigger-event-filters="type=google.cloud.storage.object.v1.finalized" \
  --trigger-event-filters="bucket=gs://${BUCKET_NAME}" \
  --entry-point=memories-thumbnail-creator
