# main.py
import os

import uvicorn
from fastapi import FastAPI

app = FastAPI(title="Awesome API")

APP_NAME = os.getenv("APP_NAME", "awesome-api")
APP_ENV = os.getenv("APP_ENV", "development")
APP_VERSION = os.getenv("APP_VERSION", "0.1.0")
SECRET_KEY = os.getenv("SECRET_KEY", "secureme")

PORT = int(os.getenv("PORT", "8080"))


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/version")
def version():
    """Return application version information."""
    return {
        "version": APP_VERSION,
        "name": APP_NAME,
        "environment": APP_ENV,
    }


@app.get("/config")
def get_config():
    return {
        "app_name": APP_NAME,
        "app_env": APP_ENV,
        "app_version": APP_VERSION,
        "secret_message": SECRET_KEY,
    }


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=PORT, reload=False)
