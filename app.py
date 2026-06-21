import os

from flask import Flask, render_template, request, redirect, url_for, flash
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient
from azure.storage.blob import BlobServiceClient

app = Flask(__name__)
app.secret_key = os.environ.get("FLASK_SECRET_KEY", "dev-secret-key")

KEY_VAULT_URL = os.environ.get("KEY_VAULT_URL")
CONTAINER_NAME = os.environ.get("STORAGE_CONTAINER_NAME", "images")


def get_container_client():
    """
    Authenticates using the App Service's managed identity (handled
    automatically by DefaultAzureCredential when running in Azure),
    fetches the storage connection string from Key Vault, and returns
    a client for the blob container. No secrets are stored in this code.
    """
    credential = DefaultAzureCredential()
    secret_client = SecretClient(vault_url=KEY_VAULT_URL, credential=credential)
    connection_string = secret_client.get_secret("StorageConnectionString").value
    blob_service_client = BlobServiceClient.from_connection_string(connection_string)
    return blob_service_client.get_container_client(CONTAINER_NAME)


@app.route("/")
def index():
    """Web Page 1: lists all blobs in the container with a download link for each."""
    container_client = get_container_client()
    blobs = []
    for blob in container_client.list_blobs():
        blob_client = container_client.get_blob_client(blob.name)
        blobs.append(
            {
                "name": blob.name,
                "url": blob_client.url,
                "size_kb": round((blob.size or 0) / 1024, 1),
            }
        )
    return render_template("index.html", blobs=blobs)


@app.route("/upload", methods=["GET", "POST"])
def upload():
    """Web Page 2: a form to upload a file/image to the storage container."""
    if request.method == "POST":
        file = request.files.get("file")
        if not file or file.filename == "":
            flash("Please choose a file to upload.")
            return redirect(url_for("upload"))

        container_client = get_container_client()
        container_client.upload_blob(name=file.filename, data=file.stream, overwrite=True)
        flash(f"Uploaded '{file.filename}' successfully.")
        return redirect(url_for("index"))

    return render_template("upload.html")


if __name__ == "__main__":
    # Used only for local testing; Azure runs this via gunicorn instead.
    app.run(host="0.0.0.0", port=8000, debug=True)
