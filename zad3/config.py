import os
from pymongo import MongoClient

MONGO_URI = os.getenv("MONGO_URI", "mongodb://mongo:27017/taskdb")
client = MongoClient(MONGO_URI)
db = client["taskdb"]
