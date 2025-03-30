from fastapi import FastAPI, Depends
from sqlalchemy.orm import Session
from .db import models, database

models.Base.metadata.create_all(bind=database.engine)

app = FastAPI()

def get_db():
    db = database.SessionLocal()
    try:
        yield db
    finally:
        db.close()

@app.get("/")
def read_root():
    return {"message": "Hello from FastAPI with DB",
            "status": "running",
            "version": "0.1.1"}

@app.post("/assets/")
def create_asset(hostname: str, ip_address: str, db: Session = Depends(get_db)):
    asset = models.Asset(hostname=hostname, ip_address=ip_address)
    db.add(asset)
    db.commit()
    db.refresh(asset)
    return asset

@app.get("/assets/")
def get_assets(db: Session = Depends(get_db)):
    return db.query(models.Asset).all()