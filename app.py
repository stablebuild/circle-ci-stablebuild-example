from importlib.metadata import distributions

from flask import Flask

app = Flask(__name__)


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/versions")
def versions():
    return {dist.name: dist.version for dist in distributions()}
