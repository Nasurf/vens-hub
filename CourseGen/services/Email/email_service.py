"""Email notification service for API key exhaustion alerts using smtplib."""

from __future__ import annotations

import datetime
import logging
import os
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from typing import Optional, Sequence

logger = logging.getLogger(__name__)

class EmailService:
    """Service for sending email notifications via SMTP."""

    def __init__(self) -> None:
        self.from_email = os.environ.get("EMAIL_FROM", "awun8191@gmail.com")
        self.from_password = os.environ.get("EMAIL_APP_PASSWORD", "nlmr ajyi jxqg ezqb")
        self.to_email = os.environ.get("EMAIL_TO", "nuesatechteam2025@gmail.com")
        self.smtp_server = os.environ.get("SMTP_SERVER", "smtp.gmail.com")
        self.smtp_port = int(os.environ.get("SMTP_PORT", "587"))
        self.enabled = os.environ.get("EMAIL_NOTIFICATIONS_ENABLED", "false").lower() == "true"
        self.topic_notifications_enabled = os.environ.get("EMAIL_TOPIC_NOTIFICATIONS_ENABLED", "true").lower() == "true"

        if self.enabled and (not self.from_email or not self.from_password):
            logger.warning("Email notifications enabled but credentials missing")
            self.enabled = False

    def send_email(self, subject: str, message: str) -> bool:
        """Send an email via SMTP."""
        if not self.enabled:
            logger.debug("Email notifications disabled, skipping message")
            return False

        try:
            # Create message
            msg = MIMEMultipart()
            msg['From'] = self.from_email
            msg['To'] = self.to_email
            msg['Subject'] = subject

            # Add message body
            msg.attach(MIMEText(message, 'plain'))

            # Create SMTP connection
            server = smtplib.SMTP(self.smtp_server, self.smtp_port)
            server.starttls()  # Secure the connection

            # Login and send
            server.login(self.from_email, self.from_password)
            text = msg.as_string()
            server.sendmail(self.from_email, self.to_email, text)

            # Clean up
            server.quit()

            logger.info("Email notification sent successfully to %s", self.to_email)
            return True

        except Exception as e:
            logger.error("Failed to send email notification: %s", e)
            return False

    def send_api_exhaustion_alert(self, exhausted_keys: int, total_keys: int, model: str, questions_generated: int = 0) -> bool:
        """Send email alert when all API keys are exhausted."""
        # Get current cache status for more details
        cache_info = self._get_cache_summary()

        subject = f"🚨 CourseGen API Keys Exhausted - Action Required"

        message = f"""
🚨 API KEYS EXHAUSTED - ACTION REQUIRED 🚨

📊 SUMMARY:
• API Keys: {exhausted_keys}/{total_keys} exhausted
• Model: {model}
• Questions Generated: {questions_generated}
• Time: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC')}

📈 CACHE DETAILS:
• Total Requests Today: {cache_info.get('total_requests', 0)}
• Total Tokens Used: {cache_info.get('total_tokens', 0)}
• Current Key Index: {cache_info.get('current_key_index', 0)}

🔧 REQUIRED ACTIONS:
1. Check your Gemini API quotas at console.cloud.google.com
2. Wait for quota reset (24 hours) or upgrade your plan
3. Add more API keys to services/Gemini/gemini_api_keys.py
4. Restart the question generation process

💡 TIP: Consider using multiple API keys with different billing accounts for better distribution.

---
This is an automated alert from CourseGen API Key Monitoring System.
"""
        return self.send_email(subject, message)

    # ------------------------------------------------------------------
    # Generation lifecycle helpers
    # ------------------------------------------------------------------

    def send_generation_started(
        self,
        courses: Sequence[str],
        *,
        theory_per_request: int,
        calc_per_request: int,
        resume: bool,
        store_firestore: bool,
        model: str,
        temperature: float,
    ) -> bool:
        """Notify when a generation run starts."""

        if not self.enabled:
            return False

        subject = "CourseGen Question Generation Started"

        course_count = len(courses)
        display_courses = ", ".join(courses[:10]) if courses else "(none)"
        if course_count > 10:
            display_courses += f" … (+{course_count - 10} more)"

        # Get API key usage information
        api_usage = self._get_api_key_usage_summary()

        message = f"""
🚀 CourseGen question generation run kicked off!

📚 Courses to process ({course_count}): {display_courses}

⚙️ Configuration:
• Model: {model}
• Temperature: {temperature}
• Theory batch size: {theory_per_request}
• Calculation batch size: {calc_per_request}
• Resume enabled: {resume}
• Firestore enabled: {store_firestore}

🕒 Start Time: {datetime.datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')}

🔑 API KEY USAGE SUMMARY:
{api_usage}

We will send another email once each course finishes.
"""

        return self.send_email(subject, message)

    def send_course_finished(
        self,
        *,
        course_code: str,
        course_title: str,
        question_count: int,
        duration_seconds: float,
        status: str = "completed",
        error: Optional[str] = None,
    ) -> bool:
        """Notify when a single course finishes processing."""

        if not self.enabled:
            return False

        subject_status = status.capitalize()
        subject = f"CourseGen: {course_code} {subject_status}"

        duration_minutes = max(duration_seconds / 60.0, 0.0)
        status_line = "✅ Course generation completed successfully" if status == "completed" else "⚠️ Course generation ended with errors"

        # Get API key usage information
        api_usage = self._get_api_key_usage_summary()

        message = f"""
{status_line}

📘 Course: {course_code} — {course_title or 'Untitled'}
📊 Questions generated: {question_count}
⏱️ Duration: {duration_minutes:.2f} minutes
🕒 Finished At: {datetime.datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')}

🔑 API KEY USAGE SUMMARY:
{api_usage}
"""

        if error:
            message += f"\n❗ Error Details: {error}\n"

        return self.send_email(subject, message)

    def send_course_started(
        self,
        *,
        course_code: str,
        course_title: str,
        total_topics: int,
        total_subtopics: int,
    ) -> bool:
        """Notify when processing for a new course begins."""

        if not self.enabled:
            return False

        subject = f"CourseGen: Starting {course_code}"

        # Get API key usage information
        api_usage = self._get_api_key_usage_summary()

        message = f"""
🚀 Beginning question generation for {course_code} — {course_title or 'Untitled'}

📚 Topics: {total_topics}
🧩 Subtopics: {total_subtopics}
🕒 Start Time: {datetime.datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')}

🔑 API KEY USAGE SUMMARY:
{api_usage}

We'll follow up when this course completes.
"""

        return self.send_email(subject, message)

    def send_topic_finished(
        self,
        *,
        course_code: str,
        course_title: str,
        topic_title: str,
        question_count: int,
        total_subtopics: int,
        completed_subtopics: int,
        errored_subtopics: int,
        duration_seconds: float,
    ) -> bool:
        """Notify when a topic (all its subtopics) finishes processing."""

        if not self.enabled or not self.topic_notifications_enabled:
            logger.debug("Topic notifications disabled, skipping topic completion message")
            return False

        status = "completed"
        if errored_subtopics > 0:
            status = "error"
        elif completed_subtopics < total_subtopics:
            status = "partial"

        subject = f"CourseGen: Topic {status.capitalize()} — {course_code} :: {topic_title}"
        duration_minutes = max(duration_seconds / 60.0, 0.0)

        # Get API key usage information
        api_usage = self._get_api_key_usage_summary()

        message = f"""
Topic processing finished for {course_code} — {course_title or 'Untitled'}

🔖 Topic: {topic_title}
📊 Questions generated in topic: {question_count}
📈 Subtopics completed: {completed_subtopics}/{total_subtopics}
⚠️ Subtopics with errors: {errored_subtopics}
⏱️ Duration: {duration_minutes:.2f} minutes
🕒 Finished At: {datetime.datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')}

🔑 API KEY USAGE SUMMARY:
{api_usage}
"""

        return self.send_email(subject, message)

    def _get_cache_summary(self) -> dict:
        """Get summary information from the API key cache."""
        try:
            cache_root = os.environ.get("COURSEGEN_CACHE_ROOT", "/app/OUTPUT_DATA2")
            cache_file = os.path.join(cache_root, "data", "gemini_cache", "api_key_cache.json")
            import json
            with open(cache_file, 'r') as f:
                data = json.load(f)

            total_requests = 0
            total_tokens = 0
            current_key_index = data.get("current_key_index", 0)

            for key_data in data.get("keys", {}).values():
                total_requests += key_data.get("rpd", 0)
                total_tokens += key_data.get("total_tokens", 0)

            return {
                "total_requests": total_requests,
                "total_tokens": total_tokens,
                "current_key_index": current_key_index
            }
        except Exception:
            return {"total_requests": 0, "total_tokens": 0, "current_key_index": 0}

    def _get_api_key_usage_summary(self) -> str:
        """Get formatted API key usage summary for email notifications."""
        try:
            cache_summary = self._get_cache_summary()
            total_requests = cache_summary.get("total_requests", 0)
            total_tokens = cache_summary.get("total_tokens", 0)
            current_key_index = cache_summary.get("current_key_index", 0)

            # Get individual key information
            cache_root = os.environ.get("COURSEGEN_CACHE_ROOT", "/app/OUTPUT_DATA2")
            cache_file = os.path.join(cache_root, "data", "gemini_cache", "api_key_cache.json")

            key_details = []
            try:
                import json
                with open(cache_file, 'r') as f:
                    data = json.load(f)

                for i, (key_id, key_data) in enumerate(data.get("keys", {}).items()):
                    requests = key_data.get("rpd", 0)
                    tokens = key_data.get("total_tokens", 0)
                    exhausted = key_data.get("exhausted", False)
                    status = "🚫 EXHAUSTED" if exhausted else "✅ ACTIVE"
                    key_details.append(f"• Key {i+1}: {requests:,} req, {tokens:,} tokens ({status})")
            except Exception:
                key_details.append("• Key details unavailable")

            summary = f"""
📊 API Usage Today:
• Total Requests: {total_requests:,}
• Total Tokens: {total_tokens:,}
• Active Key Index: {current_key_index + 1}

🔑 Key Status:
{chr(10).join(key_details)}
"""
            return summary

        except Exception as e:
            logger.warning(f"Could not get API key usage summary: {e}")
            return """
📊 API Usage Today:
• Information temporarily unavailable
"""

# Global instance
_email_service: Optional[EmailService] = None

def get_email_service() -> EmailService:
    """Get or create the global email service instance."""
    global _email_service
    if _email_service is None:
        _email_service = EmailService()
    return _email_service

def send_termination_notification(exhausted_keys: int, total_keys: int, model: str, questions_generated: int = 0) -> None:
    """Send termination notification when all API keys are exhausted."""
    try:
        service = get_email_service()
        service.send_api_exhaustion_alert(exhausted_keys, total_keys, model, questions_generated)
    except Exception as e:
        logger.error("Failed to send termination notification: %s", e)
