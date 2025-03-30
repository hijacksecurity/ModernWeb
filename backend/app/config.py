import os
from enum import Enum
from pydantic_settings import BaseSettings
from pydantic import computed_field


class Environment(str, Enum):
    DEV = "dev"
    TEST = "test"
    PROD = "prod"


class Settings(BaseSettings):
    ENV: Environment = Environment.DEV

    SQLITE_PATH: str = "../dev.db"

    DB_HOST: str = ""
    DB_PORT: int = 5432
    DB_NAME: str = ""
    DB_USER: str = ""
    DB_PASS: str = ""

    class Config:
        env_file = f".env.{os.getenv('ENV', 'dev')}"  # Dynamically loads .env.dev, .env.test, etc.

    @computed_field
    @property
    def DB_URL(self) -> str:
        if self.ENV == Environment.DEV:
            return f"sqlite:///{self.SQLITE_PATH}"
        else:
            return (
                f"postgresql://{self.DB_USER}:{self.DB_PASS}@{self.DB_HOST}:{self.DB_PORT}/{self.DB_NAME}"
            )


settings = Settings()
