import zipfile
import os
from google.cloud import storage
from google.oauth2 import service_account

BUCKET_NAME = "neuraltrust-models-artifacts"
MODELS_ZIP_NAME = "models_v3.zip"
MODELS_ZIP_PATH = "/code/kpi/bert/models/models.zip"
SERVICE_ACCOUNT_PATH = "/code/scripts/service-account.json"

def download_blob():
    """Downloads a blob from the bucket, unzips it, and removes the zip file."""
    print(SERVICE_ACCOUNT_PATH)
    credentials = service_account.Credentials.from_service_account_file(SERVICE_ACCOUNT_PATH)
    storage_client = storage.Client(credentials=credentials)
    bucket = storage_client.bucket(BUCKET_NAME)
    blob = bucket.blob(MODELS_ZIP_NAME)

    blob.download_to_filename(MODELS_ZIP_PATH)
    print(f"Blob {MODELS_ZIP_NAME} downloaded to {MODELS_ZIP_PATH}.")

    # Unzipping the file
    with zipfile.ZipFile(MODELS_ZIP_PATH, 'r') as zip_ref:
        zip_ref.extractall(MODELS_ZIP_PATH.rstrip('models.zip'))
    print(f"Unzipped {MODELS_ZIP_PATH} successfully.")

    # Removing the zip file
    os.remove(MODELS_ZIP_PATH)
    print(f"Removed {MODELS_ZIP_PATH} after unzipping.")

download_blob()

