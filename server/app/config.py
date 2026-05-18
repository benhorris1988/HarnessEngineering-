from __future__ import annotations

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="", case_sensitive=False)

    harness_port: int = 8080
    harness_db: str = Field(default="mssql", description="mssql | memory")

    mssql_host: str = "localhost"
    mssql_port: int = 1433
    mssql_db: str = "Harness"
    mssql_user: str = "sa"
    mssql_password: str = "Harness!Pass1"

    ollama_url: str = "http://localhost:11434"
    ollama_model: str = "llama3.1:8b"

    agent_max_steps: int = 12

    @property
    def odbc_connection_string(self) -> str:
        return (
            "Driver={ODBC Driver 18 for SQL Server};"
            f"Server={self.mssql_host},{self.mssql_port};"
            f"Database={self.mssql_db};"
            f"UID={self.mssql_user};PWD={self.mssql_password};"
            "Encrypt=yes;TrustServerCertificate=yes;"
        )


def get_settings() -> Settings:
    return Settings()
