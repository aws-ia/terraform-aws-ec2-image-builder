#!/bin/bash

FILE_PATH="/temp/HelloWorld.sh"
EXPECTED_CONTENT="echo 'Hello, World!'"

if [ -f "$FILE_PATH" ]; then
    FILE_CONTENT=$(cat "$FILE_PATH")
    if [ "$FILE_CONTENT" == "$EXPECTED_CONTENT" ]; then
        echo "The file $FILE_PATH contains the expected content."
    else
        echo "The file $FILE_PATH does not contain the expected content."
    fi
else
    echo "The file $FILE_PATH does not exist."
fi
