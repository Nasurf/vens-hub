import os
import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

CONFIG_FILE = os.getenv('CONFIG_FILE', 'config.json')

@dataclass
class Config:
    """Holds configurable paths and credentials for the project."""

    # File paths and directories
    pdf_directory: str = os.getenv('PDF_DIRECTORY', '')
    processed_courses_cache: str = os.getenv('PROCESSED_COURSES_CACHE', '')
    courses_json_path: str = os.getenv('COURSES_JSON_PATH', '')
    transfer_service_account_path: str = os.getenv('TRANSFER_SERVICE_ACCOUNT', '')
    reciving_service_account_path: str = os.getenv('RECEIVING_SERVICE_ACCOUNT', '')
    sample_pdf_path: str = os.getenv('SAMPLE_PDF_PATH', '')
    document_source: str = os.getenv('DOCUMENT_SOURCE', '')
    test_directory: str = os.getenv('TEST_DIRECTORY', '')
    chroma_persist_dir: str = os.getenv('CHROMA_PERSIST_DIR', 'chromadb_storage')
    collections_json_path: str = os.getenv('COLLECTIONS_JSON_PATH', 'collections.json')

    # API Keys (leave empty - handled by gemini_api_keys.py)
    gemini_api_keys: list[str] = field(default_factory=lambda: os.getenv('GEMINI_API_KEYS', '').split(','))

    # ========================================
    # GEMINI MODEL CONFIGURATION
    # ========================================

    # Model Selection
    gemini_default_model: str = os.getenv('COURSEGEN_QUESTION_MODEL', 'gemini-2.5-flash-lite')
    gemini_calc_model: str = os.getenv('COURSEGEN_CALC_MODEL', 'gemini-2.5-flash')
    gemini_embedding_model: str = 'gemini-embedding-001'
    gemini_thinking_model: str = os.getenv('GEN_QG_THINK_MODEL', 'gemini-2.5-flash-lite')
    gemma_base_model: str = os.getenv('GEN_QG_BASE_MODEL', 'gemma-3-27b-it')

    # Generation Parameters
    gemini_temperature: float = float(os.getenv('GEMINI_TEMPERATURE', '0.2'))
    gemini_top_p: float = float(os.getenv('GEMINI_TOP_P', '0.9'))
    gemini_top_k: int = int(os.getenv('GEMINI_TOP_K', '50'))
    gemini_max_output_tokens: int = int(os.getenv('GEMINI_MAX_OUTPUT_TOKENS', '10000'))

    # Thinking Configuration
    gemini_use_thinking: bool = os.getenv('USE_THINKING', 'false').lower() in ('1', 'true', 'yes')
    gemini_thinking_budget: int = int(os.getenv('THINKING_BUDGET', '12700'))

    # ========================================
    # COURSE OUTLINE GENERATION CONFIGURATION
    # ========================================

    # Outline Generation Parameters
    gen_qg_temperature: float = float(os.getenv('GEN_QG_TEMPERATURE', '0.15'))
    gen_qg_top_p: float = float(os.getenv('GEN_QG_TOP_P', '0.9'))
    gen_qg_thinking_budget: int = int(os.getenv('GEN_QG_THINK_BUDGET', '12700'))
    gen_qg_max_output_tokens: int = int(os.getenv('GEN_QG_MAX_OUT_TOKENS', '15500'))

    # RAG Configuration for Outlines
    gen_qg_rag_tau: float = float(os.getenv('GEN_QG_RAG_TAU', '0.35'))
    gen_qg_rag_min_sim: float = float(os.getenv('GEN_QG_RAG_MIN_SIM', '0.60'))
    gen_qg_rag_topk_per_query: int = int(os.getenv('GEN_QG_RAG_TOPK', '10'))
    gen_qg_rag_max_total: int = int(os.getenv('GEN_QG_RAG_MAX', '40'))

    # Subtopic RAG Configuration
    gen_qg_subtopic_rag_enabled: bool = os.getenv('GEN_QG_SUBTOPIC_RAG', '1').lower() in ('1', 'true', 'yes')
    gen_qg_sub_rag_tau: float = float(os.getenv('GEN_QG_SUB_RAG_TAU', '0.35'))
    gen_qg_sub_rag_min_sim: float = float(os.getenv('GEN_QG_SUB_RAG_MIN_SIM', '0.60'))
    gen_qg_sub_rag_topk_per_query: int = int(os.getenv('GEN_QG_SUB_RAG_TOPK', '8'))
    gen_qg_sub_rag_final_k: int = int(os.getenv('GEN_QG_SUB_RAG_FINAL_K', '8'))

    # Pacing Controls
    gen_qg_course_delay_s: float = float(os.getenv('GEN_QG_COURSE_DELAY_S', '2.0'))
    gen_qg_topic_delay_s: float = float(os.getenv('GEN_QG_TOPIC_DELAY_S', '1.0'))
    gen_qg_query_delay_s: float = float(os.getenv('GEN_QG_QUERY_DELAY_S', '0.5'))
    gen_qg_delay_jitter_frac: float = float(os.getenv('GEN_QG_JITTER_FRAC', '0.25'))

    # ========================================
    # QUESTION GENERATION CONFIGURATION
    # ========================================

    # Question Generation Parameters
    qg_rag_topk: int = int(os.getenv('RAG_TOPK', '30'))
    qg_rag_final_k: int = int(os.getenv('RAG_FINAL_K', '12'))
    qg_rag_tau: float = float(os.getenv('RAG_TAU', '0.35'))
    qg_rag_min_similarity: float = float(os.getenv('RAG_MIN_SIMILARITY', '0.6'))
    qg_rag_context_limit: int = int(os.getenv('RAG_CONTEXT_LIMIT', '8'))
    qg_latex_wrap_steps: bool = os.getenv('LATEX_WRAP_STEPS', 'true').lower() in ('1', 'true', 'yes')

    # Request Configuration
    qg_theory_questions_per_request: int = int(os.getenv('COURSEGEN_THEORY_PER_REQUEST', '10'))
    qg_calc_questions_per_request: int = int(os.getenv('COURSEGEN_CALC_PER_REQUEST', '5'))
    qg_resume: bool = os.getenv('RESUME', 'true').lower() in ('1', 'true', 'yes')
    qg_request_delay_s: float = float(os.getenv('REQUEST_DELAY', '1.5'))
    qg_delay_jitter: float = float(os.getenv('DELAY_JITTER', '0.25'))
    qg_request_attempts: int = int(os.getenv('REQUEST_ATTEMPTS', '2'))
    qg_rag_attempts: int = int(os.getenv('RAG_ATTEMPTS', '2'))
    qg_default_theory_difficulty_rank: int = int(os.getenv('COURSEGEN_THEORY_DIFFICULTY_RANK', '2'))
    qg_default_calculation_difficulty_rank: int = int(os.getenv('COURSEGEN_CALCULATION_DIFFICULTY_RANK', '2'))
    qg_disable_cache_daily_reset: bool = os.getenv('COURSEGEN_DISABLE_CACHE_DAILY_RESET', 'false').lower() in ('1', 'true', 'yes')

    # ========================================
    # CHROMADB CONFIGURATION
    # ========================================

    # ChromaDB Retrieval Parameters
    chroma_topk: int = int(os.getenv('CHROMA_TOPK', '50'))
    chroma_final_k: int = int(os.getenv('CHROMA_FINAL_K', '8'))
    chroma_tau: float = float(os.getenv('CHROMA_TAU', '0.35'))
    chroma_min_sim: float = float(os.getenv('CHROMA_MIN_SIM', '0.60'))
    chroma_seed: Optional[int] = None

    # ========================================
    # CLOUD SERVICE CONFIGURATION
    # ========================================

    # Cloudflare Workers AI
    cf_default_model: str = '@cf/baai/bge-m3'
    cf_max_batch: int = int(os.getenv('CF_EMBED_MAX_BATCH', '100'))

    # ========================================
    # LOGGING CONFIGURATION
    # ========================================

    # Log levels
    coursegen_qg_loglevel: str = os.getenv('COURSEGEN_QG_LOGLEVEL', 'INFO').upper()
    gen_qg_log_level: str = os.getenv('GEN_QG_LOG_LVL', 'INFO').upper()

    # Debug flags
    coursegen_debug: bool = os.getenv('COURSEGEN_DEBUG', '').lower() == 'true'
    coursegen_use_structured: bool = os.getenv('COURSEGEN_USE_STRUCTURED', '0').lower() in ('1', 'true', 'yes')

    # ========================================
    # PATH CONFIGURATION
    # ========================================

    # Repository paths
    repo_root: Path = field(default_factory=lambda: Path(__file__).resolve().parent)
    default_courses_json: Path = field(default_factory=lambda: Path(__file__).resolve().parent / 'data' / 'textbooks' / 'courses.json')
    default_cache_root: Path = field(default_factory=lambda: Path(__file__).resolve().parent / 'OUTPUT_DATA2' / 'cache')

    # Dynamic path resolution
    courses_json_path_resolved: Path = field(init=False)
    cache_dir_resolved: Path = field(init=False)
    chroma_out_dir_resolved: Path = field(init=False)

    def __post_init__(self):
        """Resolve dynamic paths after initialization."""
        self.courses_json_path_resolved = Path(
            os.getenv('COURSEGEN_COURSES_JSON', str(self.default_courses_json))
        ).expanduser().resolve()

        self.cache_dir_resolved = Path(
            os.getenv('COURSEGEN_CACHE_DIR', str(self.default_cache_root))
        ).expanduser().resolve()

        chroma_out_dir = self.cache_dir_resolved / 'outlines_by_chroma'
        self.chroma_out_dir_resolved = Path(
            os.getenv('COURSEGEN_CHROMA_OUT_DIR', str(chroma_out_dir))
        ).expanduser().resolve()

        # Initialize seed if provided
        seed_env = os.getenv('CHROMA_SEED')
        if seed_env and seed_env.isdigit():
            self.chroma_seed = int(seed_env)


def load_config() -> Config:
    """Load configuration from environment variables and ``config.json``."""

    config = Config()
    if os.path.exists(CONFIG_FILE):
        try:
            with open(CONFIG_FILE) as f:
                data = json.load(f)
            for field_name in config.__dataclass_fields__:
                if field_name in data:
                    setattr(config, field_name, data[field_name])
        except Exception:
            pass
    return config
