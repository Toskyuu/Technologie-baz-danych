from datetime import datetime
from typing import Optional

from bson import ObjectId
from fastapi import FastAPI

from config import db

app = FastAPI()

users_col = db["users"]
projects_col = db["projects"]
tasks_col = db["tasks"]


# Dodawanie użytkownika
@app.post("/users/")
def create_user(name: str, email: str):
    user = {"name": name, "email": email}
    result = users_col.insert_one(user)
    return {"id": str(result.inserted_id), "message": "User created"}


# Dodawanie projektu
@app.post("/projects/")
def create_project(name: str, description: str):
    project = {"name": name, "description": description}
    result = projects_col.insert_one(project)
    return {"id": str(result.inserted_id), "message": "Project created"}


# Dodawanie zadania
@app.post("/tasks/")
def create_task(title: str, description: str, status: str, user_id: str, project_id: str):
    task = {
        "title": title,
        "description": description,
        "status": status,
        "user_id": ObjectId(user_id),
        "project_id": ObjectId(project_id),
        "created_at": datetime.utcnow()
    }
    result = tasks_col.insert_one(task)
    return {"id": str(result.inserted_id), "message": "Task created"}


# Pobieranie użytkowników
@app.get("/users/")
def get_users():
    users = list(users_col.find())
    for user in users:
        user["_id"] = str(user["_id"])
    return {"users": users}


# Pobieranie projektów
@app.get("/projects/")
def get_projects():
    projects = list(projects_col.find())
    for project in projects:
        project["_id"] = str(project["_id"])
    return {"projects": projects}


# Pobieranie zadań
@app.get("/tasks/")
def get_tasks():
    tasks = list(tasks_col.find())
    for task in tasks:
        task["_id"] = str(task["_id"])
        task["user_id"] = str(task["user_id"])
        task["project_id"] = str(task["project_id"])
    return {"tasks": tasks}


# Edycja użytkownika
@app.put("/users/{user_id}")
def update_user(user_id: str, name: Optional[str] = None, email: Optional[str] = None):
    update_data = {}
    if name:
        update_data["name"] = name
    if email:
        update_data["email"] = email

    users_col.update_one({"_id": ObjectId(user_id)}, {"$set": update_data})

    return {"message": "User updated successfully"}


# Edycja projektu
@app.put("/projects/{project_id}")
def update_project(project_id: str, name: Optional[str] = None, description: Optional[str] = None):
    update_data = {}
    if name:
        update_data["name"] = name
    if description:
        update_data["description"] = description

    projects_col.update_one({"_id": ObjectId(project_id)}, {"$set": update_data})

    return {"message": "Project updated successfully"}


# Edycja zadania
@app.put("/tasks/{task_id}")
def update_task(task_id: str, title: Optional[str] = None, description: Optional[str] = None,
                status: Optional[str] = None, assigned_to: Optional[str] = None, project_id: Optional[str] = None):
    update_data = {}
    if title:
        update_data["title"] = title
    if description:
        update_data["description"] = description
    if status:
        update_data["status"] = status
    if assigned_to:
        update_data["assigned_to"] = ObjectId(assigned_to)
    if project_id:
        update_data["project_id"] = ObjectId(project_id)
    result = tasks_col.update_one({"_id": ObjectId(task_id)}, {"$set": update_data})

    return {"message": "Task updated successfully"}


# Pobieranie użytkownika i jego zadań
@app.get("/user/{user_id}/details/")
async def get_user_details(user_id: str):
    user = users_col.find_one({"_id": ObjectId(user_id)})
    tasks = list(tasks_col.find({"user_id": ObjectId(user_id)}))
    project_ids = {task["project_id"] for task in tasks}
    projects = list(projects_col.find({"_id": {"$in": list(project_ids)}}))

    user_details = {
        "user": {
            "id": str(user["_id"]),
            "name": user["name"],
            "email": user["email"]
        },
        "projects": []
    }

    for project in projects:
        project_tasks = [task for task in tasks if str(task["project_id"]) == str(project["_id"])]

        user_details["projects"].append({
            "project_id": str(project["_id"]),
            "project_name": project["name"],
            "tasks": [
                {
                    "task_id": str(task["_id"]),
                    "task_title": task["title"],
                    "task_description": task["description"],
                    "task_status": task["status"]
                } for task in project_tasks
            ]
        })

    return user_details


db.command({
    "create": "user_tasks_view",
    "viewOn": "tasks",
    "pipeline": [
        {"$lookup": {
            "from": "users",
            "localField": "user_id",
            "foreignField": "_id",
            "as": "user"
        }},
        {"$unwind": "$user"},
        {"$project": {
            "_id": 0,
            "task_id": "$_id",
            "title": 1,
            "status": 1,
            "user_name": "$user.name",
            "user_email": "$user.email"
        }}
    ]
})


@app.get("/views/user-tasks/")
def get_user_tasks_view():
    view_data = list(db["user_tasks_view"].find())
    for item in view_data:
        if "task_id" in item and isinstance(item["task_id"], ObjectId):
            item["task_id"] = str(item["task_id"])
    return {"user_tasks": view_data}


# Agregacja: liczba zakończonych zadań
@app.get("/tasks/completed-count")
def get_completed_tasks_count():
    count = tasks_col.count_documents({"status": "Completed"})
    return {"completed_tasks": count}


# Agregacja: Liczba zadań w projekcie
@app.get("/tasks/{project_id}/count")
def get_tasks_count_in_project(project_id: str):
    count = tasks_col.count_documents({"project_id": ObjectId(project_id)})
    return {"project_id": project_id, "tasks_count": count}


# Agregacja: Liczba zadań w projekcie przy pomocy aggregation pipeline

@app.get("/tasks/{project_id}/count/aggregation_pipeline")
def get_tasks_count_in_project_pipeline(project_id: str):
    pipeline = [
        {"$match": {"project_id": ObjectId(project_id)}},
        {"$group": {"_id": "$project_id", "tasks_count": {"$sum": 1}}}
    ]

    result = list(tasks_col.aggregate(pipeline))
    if not result:
        return {"project_id": project_id, "tasks_count": 0}

    return {
        "project_id": project_id,
        "tasks_count": result[0]["tasks_count"]
    }


# Agregacja: Liczba zadań dla każdego uzytkownika
@app.get("/tasks/count-by-user")
def get_task_count_by_user():
    tasks = tasks_col.find()

    users = users_col.find()

    task_count_by_user = {}

    for task in tasks:
        user_id = str(task["user_id"])
        if user_id not in task_count_by_user:
            task_count_by_user[user_id] = 0
        task_count_by_user[user_id] += 1

    result = []
    for user in users:
        user_id = str(user["_id"])
        user_name = user["name"]
        task_count = task_count_by_user.get(user_id, 0)
        result.append({
            "user_id": user_id,
            "user_name": user_name,
            "task_count": task_count
        })

    return {"task_count_by_user": result}
