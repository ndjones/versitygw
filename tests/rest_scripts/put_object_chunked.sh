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
content_encoding="$CONTENT_ENCODING"
content_length="$CONTENT_LENGTH"
decoded_content_length="$DECODED_CONTENT_LENGTH"

add_first_chunk() {

  empty_payload_hash="$(echo -n "" | sha256sum | awk '{print $1}')"
  file_hash=$(sha256sum "$data_file" | awk '{print $1}')

  chunk_sts_data="AWS4-HMAC-SHA256-PAYLOAD
$current_date_time
$year_month_day/$aws_region/s3/aws4_request
$signature
$empty_payload_hash
$file_hash"

  echo "$chunk_sts_data" > "first_chunk.txt"
  original_signature="$signature"
  create_canonical_hash_sts_and_signature "$chunk_sts_data"
  first_chunk_signature="$signature"
}

add_second_chunk() {

  empty_payload_hash="$(echo -n "" | sha256sum | awk '{print $1}')"

  chunk_sts_data="AWS4-HMAC-SHA256-PAYLOAD
$current_date_time
$year_month_day/$aws_region/s3/aws4_request
$first_chunk_signature
$empty_payload_hash
$empty_payload_hash"

  create_canonical_hash_sts_and_signature "$chunk_sts_data"
  second_chunk_signature="$signature"
}

generate_test_signature() {

  current_date_time="20130524T000000Z"
  year_month_day="20130524"
  aws_region="us-east-1"
  chunk_sts_data="AWS4-HMAC-SHA256-PAYLOAD
20130524T000000Z
20130524/us-east-1/s3/aws4_request
4f232c4386841ef735655705268965c44a0e4690baa4adea153f7db9fa80a0a9
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
bf718b6f653bebc184e1479f1935b8da974d701b893afcf49e701f3e2f9f9c5a"

  create_canonical_hash_sts_and_signature "$chunk_sts_data"
  test_signature="$signature"
}

build_canonical_request_string() {
  signed_params=""
  canonical_request="PUT
/$bucket_name/$key

"
  if [ "$content_encoding" != "" ]; then
    canonical_request+="content-encoding:$content_encoding
"
    signed_params=$(add_parameter "$signed_params" "content-encoding" ";")
  fi
  if [ "$CONTENT_LENGTH" != "" ]; then
    canonical_request+="content-length:$CONTENT_LENGTH
"
    signed_params=$(add_parameter "$signed_params" "content-length" ";")
  fi
  canonical_request+="host:$host
"
  signed_params=$(add_parameter "$signed_params" "host" ";")
  if [ "$content_encoding" != "" ]; then
    canonical_request+="transfer-encoding:chunked
"
    signed_params=$(add_parameter "$signed_params" "transfer-encoding" ";")
  fi
  if [ "$CHECKSUM" != "" ]; then
    canonical_request+="x-amz-checksum-sha256:$checksum_hash
"
    signed_params=$(add_parameter "$signed_params" "x-amz-checksum-sha256" ";")
  fi
  canonical_request+="x-amz-content-sha256:$payload_hash
"
  signed_params=$(add_parameter "$signed_params" "x-amz-content-sha256" ";")
  canonical_request+="x-amz-date:$current_date_time
"
  signed_params=$(add_parameter "$signed_params" "x-amz-date" ";")
  if [ "$DECODED_CONTENT_LENGTH" != "" ]; then
    canonical_request+="x-amz-decoded-content-length:$decoded_content_length
"
    signed_params=$(add_parameter "$signed_params" "x-amz-decoded-content-length" ";")
  fi
  canonical_request+="
$signed_params
$payload_hash"
}

current_date_time=$(date -u +"%Y%m%dT%H%M%SZ")
if [ "$CONTENT_ENCODING" == "" ]; then
  payload_hash="$(sha256sum "$data_file" | awk '{print $1}')"
else
  payload_hash="STREAMING-AWS4-HMAC-SHA256-PAYLOAD"
fi
checksum_hash="$(echo -n "$payload_hash" | xxd -r -p | base64)"

build_canonical_request_string

echo "$canonical_request" > "canonical_request.txt"

create_canonical_hash_sts_and_signature

echo "$sts_data" > "sts_data.txt"

add_first_chunk
add_second_chunk
generate_test_signature
echo "$test_signature" > "test_signature.txt"

file_data=$(cat "$data_file")

string_one="PUT /$bucket_name/$key HTTP/1.1
Host: s3.amazonaws.com
Authorization: AWS4-HMAC-SHA256 Credential=$aws_access_key_id/$year_month_day/$aws_region/s3/aws4_request,SignedHeaders=$signed_params,Signature=$signature
x-amz-content-sha256: $payload_hash
x-amz-date: $current_date_time
Content-Length: 10

$file_data

"
echo -en "${string_one//$'\n'/$'\r\n'}" > "single_command.txt"

#openssl s_client -connect s3.amazonaws.com:443
string="PUT /$bucket_name/$key HTTP/1.1
Host: s3.amazonaws.com
Authorization: AWS4-HMAC-SHA256 Credential=$aws_access_key_id/$year_month_day/$aws_region/s3/aws4_request,SignedHeaders=$signed_params,Signature=$original_signature
x-amz-content-sha256: STREAMING-AWS4-HMAC-SHA256-PAYLOAD
x-amz-date: $current_date_time
Content-Encoding: aws-chunked
x-amz-decoded-content-length: 0
Transfer-Encoding: chunked

0;chunk-signature=$first_chunk_signature

"
echo -en "${string//$'\n'/$'\r\n'}" > "chunked_command.txt"
echo -en "${string_two//$'\n'/$'\r\n'}" > "chunked_command_two.txt"
