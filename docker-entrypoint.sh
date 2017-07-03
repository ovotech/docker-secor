#!/bin/bash

set -e

if [[ ! -z "$DEBUG" ]]; then
  set -x
fi

if [[ -z "$SECOR_GROUP" ]]; then
  echo "You must specify the SECOR_GROUP variable."
  echo "  e.g., launch with -e SECOR_GROUP=consumer-group-name"
  exit 1
fi

# If BOTH are unset
if [[ -z "$ZOOKEEPER_QUORUM" && -z "$KAFKA_SEED_BROKER_HOST" ]]; then
  echo "You must set either ZOOKEEPER_QUORUM or KAFKA_SEED_BROKER_HOST."
  echo "  e.g., launch with -e ZOOKEEPER_QUORUM=zookeeper:2181 or -e KAFKA_SEED_BROKER_HOST=my.kafka.host"
  exit 1
fi

# If EITHER is unset
if [[ -z "$SECOR_S3_BUCKET" || -z "$SECOR_S3_PATH" ]]; then
  echo "You must set both SECOR_S3_BUCKET and SECOR_S3_PATH."
  echo "  e.g., launch with -e SECOR_S3_BUCKET=my-bucket -e SECOR_S3_PATH=my-path"
  exit 1
fi

# If BOTH are set
if [[ -n "$AWS_ACCESS_KEY" && -n "$AWS_SECRET_KEY" ]]; then
  # if these vars don't get exported, AWS CLI will fall back to using its own credential lookup
  export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY
  export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_KEY
fi

# Ensure we can access S3
aws s3 ls s3://$SECOR_S3_BUCKET > /dev/null

SECOR_CONFIG_FILE=/opt/secor/secor.prod.properties

# AWS Access Credentials
if [[ -n "$AWS_ACCESS_KEY" ]]; then sed -i -e "s^aws.access.key=.*$^aws.access.key=${AWS_ACCESS_KEY}^" $SECOR_CONFIG_FILE ; fi
if [[ -n "$AWS_SECRET_KEY" ]]; then sed -i -e "s^aws.secret.key=.*$^aws.secret.key=${AWS_SECRET_KEY}^" $SECOR_CONFIG_FILE ; fi

# AWS S3 Endpoint Config
if [[ -n "$AWS_REGION" ]]; then sed -i -e "s^aws.region=.*$^aws.region=${AWS_REGION}^" $SECOR_CONFIG_FILE ; fi
if [[ -n "$AWS_ENDPOINT" ]]; then sed -i -e "s^aws.endpoint=.*$^aws.endpoint=${AWS_ENDPOINT}^" $SECOR_CONFIG_FILE ; fi

# How to connect to Kafka/ZK
if [[ -n "$KAFKA_SEED_BROKER_HOST" ]]; then sed -i -e "s/kafka.seed.broker.host=.*$/kafka.seed.broker.host=${KAFKA_SEED_BROKER_HOST}/" $SECOR_CONFIG_FILE ; fi
if [[ -n "$KAFKA_SEED_BROKER_PORT" ]]; then sed -i -e "s/kafka.seed.broker.port=.*$/kafka.seed.broker.port=${KAFKA_SEED_BROKER_PORT}/" $SECOR_CONFIG_FILE ; fi
if [[ -n "$ZOOKEEPER_QUORUM" ]]; then sed -i -e "s/zookeeper.quorum=.*$/zookeeper.quorum=${ZOOKEEPER_QUORUM}/" $SECOR_CONFIG_FILE ; fi
if [[ -n "$KAFKA_ZOOKEEPER_PATH" ]]; then sed -i -e "s^kafka.zookeeper.path=.*$^kafka.zookeeper.path=${KAFKA_ZOOKEEPER_PATH}^" $SECOR_CONFIG_FILE ; fi

# Where to store things in S3 and locally within the container
sed -i -e "s/secor.s3.bucket=.*$/secor.s3.bucket=${SECOR_S3_BUCKET}/" $SECOR_CONFIG_FILE
sed -i -e "s/secor.s3.path=.*$/secor.s3.path=${SECOR_S3_PATH}/" $SECOR_CONFIG_FILE
sed -i -e "s/secor.local.path=.*$/secor.local.path=\/tmp\/${SECOR_GROUP}/" $SECOR_CONFIG_FILE

# Which Kafka topics to listen to?
if [[ -n "$SECOR_KAFKA_TOPIC_FILTER" ]]; then sed -i -e "s/secor.kafka.topic_filter=.*$/secor.kafka.topic_filter=${SECOR_KAFKA_TOPIC_FILTER}/" $SECOR_CONFIG_FILE ; fi
if [[ -n "$SECOR_KAFKA_TOPIC_BLACKLIST" ]]; then sed -i -e "s/secor.kafka.topic_blacklist=.*$/secor.kafka.topic_blacklist=${SECOR_KAFKA_TOPIC_BLACKLIST}/" $SECOR_CONFIG_FILE ; fi

# Max file size/ages
if [[ -n "$SECOR_MAX_FILE_BYTES" ]]; then sed -i -e "s/secor.max.file.size.bytes=.*$/secor.max.file.size.bytes=${SECOR_MAX_FILE_BYTES}/" $SECOR_CONFIG_FILE ; fi
if [[ -n "$SECOR_MAX_FILE_SECONDS" ]]; then sed -i -e "s/secor.max.file.age.seconds=.*$/secor.max.file.age.seconds=${SECOR_MAX_FILE_SECONDS}/" $SECOR_CONFIG_FILE ; fi

# Output config
if [[ -n "$SECOR_FILE_READER_WRITER_FACTORY" ]]; then sed -i -e "s/secor.file.reader.writer.factory=.*$/secor.file.reader.writer.factory=${SECOR_FILE_READER_WRITER_FACTORY}/" $SECOR_CONFIG_FILE ; fi
if [[ -n "$SECOR_COMPRESSION_CODEC" ]]; then sed -i -e "s/secor.compression.codec=.*$/secor.compression.codec=${SECOR_COMPRESSION_CODEC}/" $SECOR_CONFIG_FILE ; fi
if [[ -n "$SECOR_FILE_EXTENSION" ]]; then sed -i -e "s/secor.file.extension=.*$/secor.file.extension=${SECOR_FILE_EXTENSION}/" $SECOR_CONFIG_FILE ; fi

# If using Timestamp parser
if [[ -n "$SECOR_TIMESTAMP_NAME" ]]; then sed -i -e "s/message.timestamp.name=.*$/message.timestamp.name=${SECOR_TIMESTAMP_NAME}/" $SECOR_CONFIG_FILE ; fi
if [[ -n "$SECOR_TIMESTAMP_PATTERN" ]]; then sed -i -e "s/message.timestamp.input.pattern=.*$/message.timestamp.input.pattern=${SECOR_TIMESTAMP_PATTERN}/" $SECOR_CONFIG_FILE ; fi

# Partition files per hour/minute?
if [[ -n "$PARTITIONER_GRANULARITY_HOUR" ]]; then sed -i -e "s/partitioner.granularity.hour=.*$/partitioner.granularity.hour=${PARTITIONER_GRANULARITY_HOUR}/" $SECOR_CONFIG_FILE ; fi
if [[ -n "$PARTITIONER_GRANULARITY_MINUTE" ]]; then sed -i -e "s/partitioner.granularity.minute=.*$/partitioner.granularity.minute=${PARTITIONER_GRANULARITY_MINUTE}/" $SECOR_CONFIG_FILE ; fi

# Consumer configuration
if [[ -n "$SECOR_KAFKA_GROUP" ]]; then sed -i -e "s/secor.kafka.group=.*$/secor.kafka.group=${SECOR_KAFKA_GROUP}/" $SECOR_CONFIG_FILE ; fi
if [[ -n "$SECOR_MESSAGE_PARSER_CLASS" ]]; then sed -i -e "s/secor.message.parser.class=.*$/secor.message.parser.class=${SECOR_MESSAGE_PARSER_CLASS}/" $SECOR_CONFIG_FILE ; fi
if [[ -n "$SECOR_GENERATION" ]]; then sed -i -e "s/secor.generation=.*$/secor.generation=${SECOR_GENERATION}/" $SECOR_CONFIG_FILE ; fi
if [[ -n "$SECOR_CONSUMER_THREADS" ]]; then sed -i -e "s/secor.consumer.threads=.*$/secor.consumer.threads=${SECOR_CONSUMER_THREADS}/" $SECOR_CONFIG_FILE ; fi
if [[ -n "$SECOR_MESSAGES_PER_SECOND" ]]; then sed -i -e "s/secor.messages.per.second=.*$/secor.messages.per.second=${SECOR_MESSAGES_PER_SECOND}/" $SECOR_CONFIG_FILE ; fi
if [[ -n "$SECOR_OFFSETS_PER_PARTITION" ]]; then sed -i -e "s/secor.offsets.per.partition=.*$/secor.offsets.per.partition=${SECOR_OFFSETS_PER_PARTITION}/" $SECOR_CONFIG_FILE ; fi
if [[ -n "$KAFKA_OFFSETS_STORAGE" ]]; then sed -i -e "s/kafka.offsets.storage=.*$/kafka.offsets.storage=${KAFKA_OFFSETS_STORAGE}/" $SECOR_CONFIG_FILE ; fi
if [[ -n "$KAFKA_DUAL_COMMIT_ENABLED" ]]; then sed -i -e "s/kafka.dual.commit.enabled=.*$/kafka.dual.commit.enabled=${KAFKA_DUAL_COMMIT_ENABLED}/" $SECOR_CONFIG_FILE ; fi

if [[ -n "$SECOR_OSTRICH_PORT" ]]; then sed -i -e "s/ostrich.port=.*$/ostrich.port=${SECOR_OSTRICH_PORT}/" $SECOR_CONFIG_FILE ; fi

JVM_MEMORY=${JVM_MEMORY:-512m}

java -Xmx$JVM_MEMORY -ea -cp /opt/secor/secor.jar \
  -Dsecor_group=$SECOR_GROUP \
  -Dlog4j.configuration=file:/opt/secor/log4j.docker.properties \
  -Dconfig=/opt/secor/secor.prod.properties \
  com.pinterest.secor.main.ConsumerMain
