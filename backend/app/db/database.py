from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
from app.config import settings

# Use DB URL from config
engine = create_engine(settings.DB_URL, connect_args={"check_same_thread": False} if "sqlite" in settings.DB_URL else {})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()