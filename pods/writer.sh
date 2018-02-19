#!/bin/sh

while true 
do
  echo "Container $CONTAINER_NAME writing data :)" >> $DATA_PATH/writer.log
  sleep $SLEEP_DURATION
done
