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

test_mode=${TEST_MODE:=true}

# shellcheck disable=SC2153
data_file="$DATA_FILE"
# shellcheck disable=SC2153
bucket_name="$BUCKET_NAME"
# shellcheck disable=SC2153
key="$OBJECT_KEY"
# shellcheck disable=SC2153,SC2154
checksum="$CHECKSUM"

if [ "$test_mode" == "true" ]; then
  current_date_time="20130524T000000Z"
  year_month_day="20130524"
  bucket_name="examplebucket"
  key="chunkObject.txt"
  aws_access_key_id="AKIAIOSFODNN7EXAMPLE"
  aws_secret_access_key="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
  aws_region="us-east-1"
  host="s3.amazonaws.com"
else
  current_date_time=$(date -u +"%Y%m%dT%H%M%SZ")
  year_month_day=$(echo "$current_date_time" | cut -c1-8)
  bucket_name="versity-gwtest-bucket-luke-four-2"
  key="chunkObject.txt"
fi

canonical_request="PUT
/$bucket_name/$key

content-encoding:aws-chunked
content-length:66824
host:s3.amazonaws.com
x-amz-content-sha256:STREAMING-AWS4-HMAC-SHA256-PAYLOAD
x-amz-date:$current_date_time
x-amz-decoded-content-length:66560
x-amz-storage-class:REDUCED_REDUNDANCY

content-encoding;content-length;host;x-amz-content-sha256;x-amz-date;x-amz-decoded-content-length;x-amz-storage-class
STREAMING-AWS4-HMAC-SHA256-PAYLOAD"

if [ "$test_mode" == "true" ]; then
  expected_canonical_request="PUT
/examplebucket/chunkObject.txt

content-encoding:aws-chunked
content-length:66824
host:s3.amazonaws.com
x-amz-content-sha256:STREAMING-AWS4-HMAC-SHA256-PAYLOAD
x-amz-date:20130524T000000Z
x-amz-decoded-content-length:66560
x-amz-storage-class:REDUCED_REDUNDANCY

content-encoding;content-length;host;x-amz-content-sha256;x-amz-date;x-amz-decoded-content-length;x-amz-storage-class
STREAMING-AWS4-HMAC-SHA256-PAYLOAD"
  if [ "$expected_canonical_request" != "$canonical_request" ]; then
    echo "canonical request mismatch ($canonical_request)"
    exit 1
  fi
fi

create_canonical_hash_sts_and_signature

if [ "$test_mode" == "true" ]; then
  expected_sts_data="AWS4-HMAC-SHA256
20130524T000000Z
20130524/us-east-1/s3/aws4_request
cee3fed04b70f867d036f722359b0b1f2f0e5dc0efadbc082b76c4c60e316455"
  if [ "$sts_data" != "$expected_sts_data" ]; then
    echo "first STS data mismatch ($sts_data)"
    exit 1
  fi
fi

first_signature="$signature"

if [ "$test_mode" == "true" ] && [ "$first_signature" != "4f232c4386841ef735655705268965c44a0e4690baa4adea153f7db9fa80a0a9" ]; then
  echo "Mismatched first signature ($first_signature)"
  exit 1
fi

dd if=/dev/zero bs=1 count=66560 | tr '\0' 'a' > "as.txt"

first_payload_hash="$(head -c 65536 "as.txt" | sha256sum | awk '{print $1}')"
echo "$first_payload_hash" > "first_payload_hash.txt"

chunk_one_sts="AWS4-HMAC-SHA256-PAYLOAD
$current_date_time
$year_month_day/$aws_region/s3/aws4_request
$first_signature
$(echo -n "" | sha256sum | awk '{print $1}')
$first_payload_hash"

if [ "$test_mode" == "true" ]; then
  expected_first_chunk_data="AWS4-HMAC-SHA256-PAYLOAD
20130524T000000Z
20130524/us-east-1/s3/aws4_request
4f232c4386841ef735655705268965c44a0e4690baa4adea153f7db9fa80a0a9
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
bf718b6f653bebc184e1479f1935b8da974d701b893afcf49e701f3e2f9f9c5a"
  if [ "$chunk_one_sts" != "$expected_first_chunk_data" ]; then
    echo "first chunk STS data mismatch ($chunk_one_sts)"
    exit 1
  fi
fi

echo "$chunk_one_sts" >> "chunk_one.txt"

create_canonical_hash_sts_and_signature "$chunk_one_sts"
echo "$signature" > "signature_two.txt"
second_signature="$signature"

if [ "$test_mode" == "true" ] && [ "$second_signature" != "ad80c730a21e5b8d04586a2213dd63b9a0e99e0e2307b0ade35a65485a288648" ]; then
  echo "Mismatched second signature ($second_signature)"
  exit 1
fi

second_payload_hash="$(head -c 1024 "as.txt" | sha256sum | awk '{print $1}')"
echo "$second_payload_hash" > "second_payload_hash.txt"

chunk_two_sts="AWS4-HMAC-SHA256-PAYLOAD
$current_date_time
$year_month_day/$aws_region/s3/aws4_request
$second_signature
$(echo -n "" | sha256sum | awk '{print $1}')
$second_payload_hash"

if [ "$test_mode" == "true" ]; then
  expected_second_chunk_data="AWS4-HMAC-SHA256-PAYLOAD
20130524T000000Z
20130524/us-east-1/s3/aws4_request
ad80c730a21e5b8d04586a2213dd63b9a0e99e0e2307b0ade35a65485a288648
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
2edc986847e209b4016e141a6dc8716d3207350f416969382d431539bf292e4a"
  if [ "$chunk_two_sts" != "$expected_second_chunk_data" ]; then
    echo "second chunk STS data mismatch ($chunk_two_sts)"
    exit 1
  fi
fi

echo "$chunk_two_sts" >> "chunk_two.txt"

create_canonical_hash_sts_and_signature "$chunk_two_sts"
echo "$signature" > "signature_three.txt"
third_signature="$signature"

if [ "$test_mode" == "true" ] && [ "$third_signature" != "0055627c9e194cb4542bae2aa5492e3c1575bbb81b612b7d234b86a503ef5497" ]; then
  echo "Mismatched third signature ($third_signature)"
  exit 1
fi

chunk_three_sts="AWS4-HMAC-SHA256-PAYLOAD
$current_date_time
$year_month_day/$aws_region/s3/aws4_request
$third_signature
$(echo -n "" | sha256sum | awk '{print $1}')
$(echo -n "" | sha256sum | awk '{print $1}')"

if [ "$test_mode" == "true" ]; then
  expected_third_chunk_data="AWS4-HMAC-SHA256-PAYLOAD
20130524T000000Z
20130524/us-east-1/s3/aws4_request
0055627c9e194cb4542bae2aa5492e3c1575bbb81b612b7d234b86a503ef5497
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  if [ "$chunk_three_sts" != "$expected_third_chunk_data" ]; then
    echo "third chunk STS data mismatch ($chunk_three_sts)"
    exit 1
  fi
fi

create_canonical_hash_sts_and_signature "$chunk_three_sts"
echo "$signature" > "signature_four.txt"
fourth_signature="$signature"

if [ "$test_mode" == "true" ] && [ "$fourth_signature" != "b6c6ea8a5354eaf15b3cb7646744f4275b71ea724fed81ceb9323e279d449df9" ]; then
  echo "Mismatched fourth signature ($fourth_signature)"
  exit 1
fi

command="PUT /$bucket_name/$key HTTP/1.1
Host: $host
x-amz-date: $current_date_time
x-amz-storage-class: REDUCED_REDUNDANCY
Authorization: AWS4-HMAC-SHA256 Credential=$aws_access_key_id/$year_month_day/$aws_region/s3/aws4_request,SignedHeaders=content-encoding;content-length;host;x-amz-content-sha256;x-amz-date;x-amz-decoded-content-length;x-amz-storage-class,Signature=$first_signature
x-amz-content-sha256: STREAMING-AWS4-HMAC-SHA256-PAYLOAD
Content-Encoding: aws-chunked
x-amz-decoded-content-length: 66560
Content-Length: 66824

"

if [ "$test_mode" == "true" ]; then
  expected_command="PUT /examplebucket/chunkObject.txt HTTP/1.1
Host: s3.amazonaws.com
x-amz-date: 20130524T000000Z
x-amz-storage-class: REDUCED_REDUNDANCY
Authorization: AWS4-HMAC-SHA256 Credential=AKIAIOSFODNN7EXAMPLE/20130524/us-east-1/s3/aws4_request,SignedHeaders=content-encoding;content-length;host;x-amz-content-sha256;x-amz-date;x-amz-decoded-content-length;x-amz-storage-class,Signature=4f232c4386841ef735655705268965c44a0e4690baa4adea153f7db9fa80a0a9
x-amz-content-sha256: STREAMING-AWS4-HMAC-SHA256-PAYLOAD
Content-Encoding: aws-chunked
x-amz-decoded-content-length: 66560
Content-Length: 66824

"
  if [ "$command" != "$expected_command" ]; then
    echo "command mismatch ($command)"
    exit 1
  fi
fi


content="10000;chunk-signature=$second_signature
$(head -c 65536 "as.txt")
400;chunk-signature=$third_signature
$(head -c 1024 "as.txt")
0;chunk-signature=$fourth_signature

"
command+="$content"
command="${command//$'\n'/$'\r\n'}"
echo -n "$command" > "command.txt"
