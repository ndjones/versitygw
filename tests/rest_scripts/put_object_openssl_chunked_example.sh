#!/usr/bin/env bash

# Copyright 2024 Versity Software
# This file is licensed under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http:#www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

source ./tests/rest_scripts/rest.sh

# Fields

# shellcheck disable=SC2153
data_file="$DATA_FILE"
# shellcheck disable=SC2153
bucket_name="$BUCKET_NAME"
# shellcheck disable=SC2153
key="$OBJECT_KEY"
# shellcheck disable=SC2153,SC2154
checksum="$CHECKSUM"

current_date_time="20130524T000000Z"
year_month_day="20130524"

canonical_request="PUT
/examplebucket/chunkObject.txt

content-encoding:aws-chunked
content-length:66824
host:s3.amazonaws.com
x-amz-content-sha256:STREAMING-AWS4-HMAC-SHA256-PAYLOAD
x-amz-date:$current_date_time
x-amz-decoded-content-length:66560
x-amz-storage-class:REDUCED_REDUNDANCY

content-encoding;content-length;host;x-amz-content-sha256;x-amz-date;x-amz-decoded-content-length;x-amz-storage-class
STREAMING-AWS4-HMAC-SHA256-PAYLOAD"

aws_access_key_id=AKIAIOSFODNN7EXAMPLE
aws_secret_access_key=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

create_canonical_hash_sts_and_signature

echo "$sts_data" > "sts_data.txt"
echo "$signature" > "signature.txt"

dd if=/dev/zero bs=1 count=66560 | tr '\0' 'a' > "as.txt"

payload_hash="$(head -c 65536 "as.txt" | sha256sum | awk '{print $1}')"
echo "$payload_hash" > "payload_hash.txt"

  string_one="PUT /$bucket_name/$key HTTP/1.1
Host: $host
Authorization: AWS4-HMAC-SHA256 Credential=$aws_access_key_id/$year_month_day/$aws_region/s3/aws4_request,SignedHeaders=$signed_params,Signature=$signature
x-amz-content-sha256: $payload_hash
x-amz-date: $current_date_time
Content-Length: $(wc -c "$DATA_FILE" | awk '{print $1}')

$(cat "$DATA_FILE")

"
echo -en "${string_one//$'\n'/$'\r\n'}"
