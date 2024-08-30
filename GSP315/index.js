const functions = require('@google-cloud/functions-framework');
const crc32 = require("fast-crc32c");
const { Storage } = require('@google-cloud/storage');
const gcs = new Storage();
const { PubSub } = require('@google-cloud/pubsub');
const imagemagick = require("imagemagick-stream");

functions.cloudEvent('memories-thumbnail-creator', cloudEvent => {
  try {
    const event = cloudEvent.data;

    console.log(`Event ID: ${cloudEvent.id}`);
    console.log(`Event Type: ${cloudEvent.type}`);

    console.log(`Bucket: ${event.bucket}`);
    console.log(`File: ${event.name}`);
    console.log(`Metageneration: ${event.metageneration}`);
    console.log(`Created: ${event.timeCreated}`);
    console.log(`Updated: ${event.updated}`);

    console.log(`Event: ${event}`);
    console.log(`Hello ${event?.bucket}`);

    const fileName = event.name;
    const bucketName = event.bucket;
    const size = "64x64"
    const bucket = gcs.bucket(bucketName);
    const topicName = "topic-memories-304";
    console.log("topicnae:", topicName);

    const pubsub = new PubSub();
    console.log("pubsub:", pubsub);

    if (fileName.search("64x64_thumbnail") == -1) {
      // doesn't have a thumbnail, get the filename extension
      var filename_split = fileName.split('.');
      var filename_ext = filename_split[filename_split.length - 1];
      var filename_without_ext = fileName.substring(0, fileName.length - filename_ext.length);
      if (filename_ext.toLowerCase() == 'png' || filename_ext.toLowerCase() == 'jpg') {
        // only support png and jpg at this point
        console.log(`Processing Original: gs://${bucketName}/${fileName}`);
        const gcsObject = bucket.file(fileName);
        let newFilename = filename_without_ext + size + '_thumbnail.' + filename_ext;
        let gcsNewObject = bucket.file(newFilename);

        console.log("before image-magic");
        let srcStream = gcsObject.createReadStream();
        console.log("bucket stream:", srcStream);
        
        let dstStream = gcsNewObject.createWriteStream();
        let resize = imagemagick().resize(size).quality(90);
        srcStream.pipe(resize).pipe(dstStream);

        console.log("before the promise");
        return new Promise((resolve, reject) => {
          dstStream
            .on("error", (err) => {
              console.log(`Error*: ${err}`);
              reject(err);
            })
            .on("finish", () => {
              console.log(`Success: ${fileName} → ${newFilename}`);
              // set the content-type
              gcsNewObject.setMetadata(
                {
                  contentType: 'image/' + filename_ext.toLowerCase()
                }, function (err, apiResponse) { });
              pubsub
                .topic(topicName)
                .publisher()
                .publish(Buffer.from(newFilename))
                .then(messageId => {
                  console.log(`Message ${messageId} published.`);
                })
                .catch(err => {
                  console.error('ERROR:', err);
                });
            });
        });
      }
      else {
        console.log(`gs://${bucketName}/${fileName} is not an image I can handle`);
      }
    }
    else {
      console.log(`gs://${bucketName}/${fileName} already has a thumbnail`);
    }
  } catch (err) {
    console.error(err);
  }
});
