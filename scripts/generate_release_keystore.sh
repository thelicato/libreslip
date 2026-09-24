#!/usr/bin/env bash

set -euo pipefail

script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_directory="$(cd "$script_directory/.." && pwd)"
keystore_path="$project_directory/android/app/libreslip-release.jks"
properties_path="$project_directory/android/key.properties"
key_alias="libreslip"
default_distinguished_name="CN=LibreSlip, O=thelicato, C=IT"

if [[ ! -t 0 ]]; then
  printf 'Run this script from an interactive terminal.\n' >&2
  exit 1
fi

if ! command -v keytool > /dev/null 2>&1; then
  printf 'keytool was not found. Install a JDK and try again.\n' >&2
  exit 1
fi

if [[ -e "$keystore_path" || -e "$properties_path" ]]; then
  printf 'Signing files already exist. Nothing was overwritten.\n' >&2
  printf 'Keystore: %s\n' "$keystore_path" >&2
  printf 'Properties: %s\n' "$properties_path" >&2
  exit 1
fi

printf 'The certificate name is public and will be visible in signed APKs.\n'
read -r -p "Certificate name [$default_distinguished_name]: " distinguished_name
distinguished_name="${distinguished_name:-$default_distinguished_name}"

while true; do
  read -r -s -p 'Signing password, at least 12 characters: ' signing_password
  printf '\n'
  read -r -s -p 'Confirm signing password: ' signing_password_confirmation
  printf '\n'

  if [[ ${#signing_password} -lt 12 ]]; then
    printf 'The password must contain at least 12 characters.\n' >&2
    continue
  fi

  if [[ "$signing_password" == *'\'* ]]; then
    printf 'The password cannot contain a backslash.\n' >&2
    continue
  fi

  if [[ "$signing_password" != "$signing_password_confirmation" ]]; then
    printf 'The passwords do not match.\n' >&2
    continue
  fi

  break
done

umask 077
export LIBRESLIP_SETUP_PASSWORD="$signing_password"
trap 'unset LIBRESLIP_SETUP_PASSWORD signing_password signing_password_confirmation' EXIT

keytool -genkeypair -v -noprompt \
  -keystore "$keystore_path" \
  -storetype PKCS12 \
  -keyalg RSA \
  -keysize 4096 \
  -validity 10000 \
  -alias "$key_alias" \
  -storepass:env LIBRESLIP_SETUP_PASSWORD \
  -keypass:env LIBRESLIP_SETUP_PASSWORD \
  -dname "$distinguished_name"

{
  printf 'storePassword=%s\n' "$signing_password"
  printf 'keyPassword=%s\n' "$signing_password"
  printf 'keyAlias=%s\n' "$key_alias"
  printf 'storeFile=libreslip-release.jks\n'
} > "$properties_path"

chmod 600 "$keystore_path" "$properties_path"

keytool -list \
  -keystore "$keystore_path" \
  -storepass:env LIBRESLIP_SETUP_PASSWORD \
  -alias "$key_alias" > /dev/null

unset LIBRESLIP_SETUP_PASSWORD signing_password signing_password_confirmation
trap - EXIT

printf '\nRelease signing files created and verified.\n'
printf 'Keystore: %s\n' "$keystore_path"
printf 'Properties: %s\n' "$properties_path"
printf '\nBack up both files securely before publishing LibreSlip.\n'
printf 'Neither file is tracked by Git.\n'
