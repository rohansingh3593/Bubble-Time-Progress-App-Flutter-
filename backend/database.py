import os

from dotenv import load_dotenv
from motor.motor_asyncio import AsyncIOMotorClient

load_dotenv()

MONGO_URL = os.getenv("MONGO_URL", "mongodb://localhost:27017")
MONGO_DATABASE = os.getenv("MONGO_DATABASE", "momentum_task_app")

client = AsyncIOMotorClient(MONGO_URL)
db = client[MONGO_DATABASE]

tasks_collection = db["tasks"]
