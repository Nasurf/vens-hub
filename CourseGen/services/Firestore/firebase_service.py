"""Firestore wrapper with Question model support."""

from __future__ import annotations

from typing import List, Optional

import firebase_admin
from firebase_admin import credentials, firestore

from config import load_config
from data_models.course_model import CourseModel
from data_models.document_model import Document
from data_models.question_model import Question


class FireStore:
    _instance = None

    def __new__(cls, *args, **kwargs):
        if not cls._instance:
            cls._instance = super().__new__(cls)
        return cls._instance

    def __init__(self) -> None:
        if hasattr(self, "db"):
            return
        if not firebase_admin._apps:  # type: ignore[attr-defined]
            config = load_config()
            try:
                cred_path = config.firestore_service_account
                cred = credentials.Certificate(cred_path)
                firebase_admin.initialize_app(cred)
                self.db = firestore.client()
                print("Firebase initialized successfully.")
            except Exception as exc:  # pragma: no cover - env specific
                print(f"Error initializing Firebase: {exc}")
                self.db = None
        else:
            self.db = firestore.client()

    # ------------------------------------------------------------------
    # Course helpers
    # ------------------------------------------------------------------
    def get_course_by_code(self, course_code: str) -> Optional[CourseModel]:
        """Fetch a single course from Firestore by its course code."""

        if not self.db:
            return None
        try:
            doc_ref = self.db.collection("course_data").document(course_code)
            doc = doc_ref.get()
            if doc.exists:
                return CourseModel(**doc.to_dict())
            return None
        except Exception as exc:  # pragma: no cover - network dependent
            print(f"Error fetching course by code: {exc}")
            return None

    def get_all_documents(self) -> List[Document]:
        """Fetch all document metadata from the 'documents' collection."""

        if not self.db:
            return []
        try:
            docs_ref = self.db.collection("documents").order_by(
                "upload_timestamp", direction=firestore.Query.DESCENDING
            )
            docs = docs_ref.stream()
            return [Document(**doc.to_dict()) for doc in docs]
        except Exception as exc:  # pragma: no cover - network dependent
            print(f"Error fetching all documents: {exc}")
            return []

    def add_document(self, document: Document) -> None:
        """Add a new document's metadata to Firestore."""

        if not self.db:
            return
        try:
            doc_ref = self.db.collection("documents").document(document.file_name)
            doc_ref.set(document.model_dump())
            print(f"Successfully added document: {document.file_name}")
        except Exception as exc:  # pragma: no cover - network dependent
            print(f"Error adding document: {exc}")

    def set_question(self, question: Question) -> None:
        """Persist a generated question in a subcollection under the course document.
        
        Structure: Questions/{course_code}/questions/{auto_id}
        """
        if not self.db:
            return
        try:
            course_code = question.course_code.strip()
            if not course_code:
                print("Error: Question missing course_code")
                return
            
            payload = question.model_dump()
            if "created_at" not in payload:
                payload["created_at"] = firestore.SERVER_TIMESTAMP
            
            # Store in subcollection: Questions/{course_code}/questions/{auto_id}
            self.db.collection("Questions").document(course_code).collection("questions").document().set(payload)
        except Exception as exc:  # pragma: no cover - network dependent
            print(f"Error setting question: {exc}")

    def update_generation_progress(
        self,
        course_code: str,
        course_title: str,
        department: str,
        status: str,
        total_topics: int,
        completed_topics: int,
        total_questions: int,
        completed_questions: int,
        errored_topics: int = 0,
    ) -> None:
        """Update coarse-grained progress in GenerationProgress collection."""

        if not self.db:
            return
        try:
            progress_data = {
                "course_code": course_code,
                "course_title": course_title,
                "department": department,
                "status": status,  # "in_progress" | "completed" | "error"
                "total_topics": total_topics,
                "completed_topics": completed_topics,
                "errored_topics": errored_topics,
                "total_questions": total_questions,
                "completed_questions": completed_questions,
                "updated_at": firestore.SERVER_TIMESTAMP,
            }
            if status == "completed":
                progress_data["completed_at"] = firestore.SERVER_TIMESTAMP
            doc_ref = self.db.collection("GenerationProgress").document(course_code)
            doc_ref.set(progress_data)
        except Exception as exc:  # pragma: no cover - network dependent
            print(f"Error updating generation progress: {exc}")


if __name__ == "__main__":  # pragma: no cover - manual sanity checks
    store = FireStore()
    if store.db:
        course = store.get_course_by_code("EEE 301")
        if course:
            print("Found course:", course.title)
        else:
            print("Course not found.")

        all_docs = store.get_all_documents()
        print(f"Found {len(all_docs)} documents.")
